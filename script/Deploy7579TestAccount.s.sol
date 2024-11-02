// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors, max-states-count */

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { EmailAccountRecovery } from
    "@zk-email/ether-email-auth-contracts/src/EmailAccountRecovery.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { RhinestoneModuleKit } from "modulekit/ModuleKit.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IEntryPoint, ENTRYPOINT_ADDR } from "modulekit/test/predeploy/EntryPoint.sol";
import { PackedUserOperation } from "erc7579-implementation/src/interfaces/IERC4337Account.sol";
import { MSABasic } from "erc7579-implementation/src/MSABasic.sol";
import { MSAFactory } from "erc7579-implementation/src/MSAFactory.sol";
import { Bootstrap, BootstrapConfig } from "erc7579-implementation/src/utils/Bootstrap.sol";
import { MockHook, MockTarget } from "modulekit/Mocks.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579-implementation/src/lib/ExecutionLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract Deploy7579TestAccountScript is RhinestoneModuleKit, Script {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;
    using Strings for address;

    uint256 public privKey;
    address public deployer;
    MSABasic public msaBasicImpl;
    MSAFactory public msaFactory;
    Bootstrap public bootstrap;
    MockHook public hook;
    MockTarget public mockTarget;

    bytes32 public accountSalt;
    address public validatorAddr;
    address public recoveryModuleAddr;
    address[] public guardians = new address[](0);
    uint256[] public guardianWeights = new uint256[](0);

    address public account;
    bytes public initCode;
    bytes public userOpCalldata;
    PackedUserOperation public userOp;
    bytes32 public userOpHash;

    bytes4 public functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));

    uint256 public salt = vm.envOr("CREATE2_SALT", uint256(0));

    function run() public {
        privKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privKey);
        deployer = vm.addr(privKey);

        accountSalt = vm.envBytes32("ACCOUNT_SALT");
        require(accountSalt != bytes32(0), "ACCOUNT_SALT is required");

        address msaBasicImplAddr = vm.envOr("MSA_BASIC_IMPL", address(0));
        if (msaBasicImplAddr == address(0)) {
            msaBasicImplAddr = address(new MSABasic{ salt: bytes32(salt) }());
            console.log("Deployed MSABasic at", msaBasicImplAddr);
        }
        msaBasicImpl = MSABasic(payable(msaBasicImplAddr));

        address msaFactoryAddr = vm.envOr("MSA_FACTORY", address(0));
        if (msaFactoryAddr == address(0)) {
            msaFactoryAddr = address(new MSAFactory{ salt: bytes32(salt) }(msaBasicImplAddr));
            console.log("Deployed MSAFactory at", msaFactoryAddr);
        }
        msaFactory = MSAFactory(msaFactoryAddr);

        address bootstrapAddr = vm.envOr("BOOTSTRAP", address(0));
        if (bootstrapAddr == address(0)) {
            bootstrapAddr = address(new Bootstrap{ salt: bytes32(salt) }());
            console.log("Deployed Bootstrap at", bootstrapAddr);
        }
        bootstrap = Bootstrap(payable(bootstrapAddr));

        address hookAddr = vm.envOr("HOOK", address(0));
        if (hookAddr == address(0)) {
            hookAddr = address(new MockHook{ salt: bytes32(salt) }());
            console.log("Deployed MockHook at", hookAddr);
        }
        hook = MockHook(hookAddr);

        address mockTargetAddr = vm.envOr("MOCK_TARGET", address(0));
        if (mockTargetAddr == address(0)) {
            mockTargetAddr = address(new MockTarget{ salt: bytes32(salt) }());
            console.log("Deployed MockTarget at", mockTargetAddr);
        }
        mockTarget = MockTarget(mockTargetAddr);

        validatorAddr = vm.envOr("VALIDATOR", address(0));
        if (validatorAddr == address(0)) {
            validatorAddr = address(new OwnableValidator{ salt: bytes32(salt) }());
            console.log("Deployed Ownable Validator at", validatorAddr);
        }

        // Create initcode to be sent to Factory
        BootstrapConfig[] memory validators = new BootstrapConfig[](1);
        address accountOwner = vm.envOr("OWNER", deployer);
        recoveryModuleAddr = vm.envAddress("RECOVERY_MODULE");
        require(recoveryModuleAddr != address(0), "RECOVERY_MODULE is required");
        validators[0] = BootstrapConfig({
            module: validatorAddr,
            data: abi.encode(accountOwner, recoveryModuleAddr)
        });

        BootstrapConfig[] memory executors = new BootstrapConfig[](1);

        bytes memory recoveryModuleInstallData = abi.encode(
            validatorAddr,
            bytes("0"),
            functionSelector,
            guardians,
            guardianWeights,
            0,
            vm.envOr("RECOVERY_DELAY", uint256(1 seconds)),
            vm.envOr("RECOVERY_EXPIRY", uint256(2 weeks))
        );
        executors[0] =
            BootstrapConfig({ module: recoveryModuleAddr, data: recoveryModuleInstallData });
        BootstrapConfig memory hookConfig = BootstrapConfig({ module: hookAddr, data: bytes("") });
        BootstrapConfig[] memory fallbacks = new BootstrapConfig[](0);
        bytes memory _initCode =
            bootstrap._getInitMSACalldata(validators, executors, hookConfig, fallbacks);
        account = msaFactory.getAddress(accountSalt, _initCode);
        console.log("Account address", account);
        console.log("Account code size", account.code.length);
        initCode = abi.encodePacked(
            address(msaFactory),
            abi.encodeWithSelector(msaFactory.createAccount.selector, accountSalt, _initCode)
        );

        {
            // Add an EmailAuth guardian
            address guardianAddr = EmailAccountRecovery(recoveryModuleAddr).computeEmailAuthAddress(
                account, accountSalt
            );
            console.log("Guardian's EmailAuth address", guardianAddr);
            userOpCalldata = abi.encodeCall(
                IERC7579Account.execute,
                (
                    ModeLib.encodeSimpleSingle(),
                    ExecutionLib.encodeSingle(
                        address(recoveryModuleAddr),
                        uint256(0),
                        abi.encodeCall(IGuardianManager.addGuardian, (guardianAddr, 1))
                    )
                )
            );
        }
        console.log("nonce", getNonce(account, validatorAddr));
        userOp = PackedUserOperation({
            sender: account,
            nonce: getNonce(account, validatorAddr),
            initCode: initCode,
            callData: userOpCalldata,
            accountGasLimits: bytes32(abi.encodePacked(uint128(1e6), uint128(3e5))),
            preVerificationGas: 1e5,
            gasFees: bytes32(abi.encodePacked(uint128(0), uint128(0))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
        {
            userOpHash = IEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOp);
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(privKey, ECDSA.toEthSignedMessageHash(userOpHash));
            userOp.signature = abi.encodePacked(r, s, v);
        }

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        console.log("init userOps are ready");
        IEntryPoint(ENTRYPOINT_ADDR).handleOps{ gas: 1e6 }(userOps, payable(deployer));
        console.log("init UserOps are executed");

        // set threshold to 1.
        {
            // Add an EmailAuth guardian
            address guardianAddr = EmailAccountRecovery(recoveryModuleAddr).computeEmailAuthAddress(
                account, accountSalt
            );
            console.log("Guardian's EmailAuth address", guardianAddr);
            userOpCalldata = abi.encodeCall(
                IERC7579Account.execute,
                (
                    ModeLib.encodeSimpleSingle(),
                    ExecutionLib.encodeSingle(
                        address(recoveryModuleAddr),
                        uint256(0),
                        abi.encodeCall(IGuardianManager.changeThreshold, 1)
                    )
                )
            );
        }
        userOp = PackedUserOperation({
            sender: account,
            nonce: getNonce(account, validatorAddr),
            initCode: bytes(""),
            callData: userOpCalldata,
            accountGasLimits: bytes32(abi.encodePacked(uint128(1e5), uint128(1e6))),
            preVerificationGas: 1e5,
            gasFees: bytes32(abi.encodePacked(uint128(0), uint128(0))),
            paymasterAndData: bytes(""),
            signature: bytes("")
        });
        {
            userOpHash = IEntryPoint(ENTRYPOINT_ADDR).getUserOpHash(userOp);
            (uint8 v, bytes32 r, bytes32 s) =
                vm.sign(privKey, ECDSA.toEthSignedMessageHash(userOpHash));
            userOp.signature = abi.encodePacked(r, s, v);
        }
        userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        console.log("changeThreshold userOps are ready");
        IEntryPoint(ENTRYPOINT_ADDR).handleOps{ gas: 3e6 }(userOps, payable(deployer));
        console.log("changeThreshold UserOps are executed");

        vm.stopBroadcast();
    }

    function getNonce(
        address smartAccount,
        address validator
    )
        internal
        view
        returns (uint256 nonce)
    {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        nonce = IEntryPoint(ENTRYPOINT_ADDR).getNonce(address(smartAccount), key);
    }
}
