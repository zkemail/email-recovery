import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { SafeFactory, IAccountFactory } from "src/test/SafeFactory.sol";
import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { RhinestoneModuleKit } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAccountRecovery } from
    "ether-email-auth/packages/contracts/src/EmailAccountRecovery.sol";
import { PackedUserOperation } from "erc7579-implementation/src/interfaces/IERC4337Account.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { MockValidator } from "modulekit/Mocks.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { IEntryPoint, ENTRYPOINT_ADDR } from "modulekit/test/predeploy/EntryPoint.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ExecutionLib } from "erc7579-implementation/src/lib/ExecutionLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { Safe7579Launchpad, IERC7484 } from "safe7579/Safe7579Launchpad.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { SafeProxy } from "@safe-global/safe-contracts/contracts/proxies/SafeProxy.sol";
import { SafeProxyFactory } from
    "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import { Safe7579 } from "safe7579/Safe7579.sol";

contract InstallModuleSafe7579AccountScript is RhinestoneModuleKit, Script {
    uint256 privKey;
    address owner;

    address account;

    address managerAddr;
    address moduleAddr;
    bytes32 accountSalt;
    address validator;
    address payable safe7579;

    bytes userOpCalldata;
    PackedUserOperation userOp;
    bytes isInstalledContext = bytes("0");
    bytes4 functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

    function run() public {
        privKey = vm.envUint("PRIVATE_KEY");
        require(privKey != uint256(0), "PRIVATE_KEY is required");

        owner = vm.envAddress("SIGNER");
        require(owner != address(0), "SIGNER is required");

        accountSalt = vm.envBytes32("ACCOUNT_SALT");
        require(accountSalt != bytes32(0), "ACCOUNT_SALT is required");

        managerAddr = vm.envAddress("RECOVERY_MANAGER");
        require(managerAddr != address(0), "RECOVERY_MANAGER is required");

        moduleAddr = vm.envAddress("RECOVERY_MODULE");
        require(moduleAddr != address(0), "RECOVERY_MODULE is required");

        validator = vm.envAddress("VALIDATOR");
        require(validator != address(0), "VALIDATOR is required");

        safe7579 = payable(vm.envAddress("SAFE_7579"));
        require(safe7579 != address(0), "SAFE_7579 is required");

        account = vm.envAddress("ACCOUNT");
        require(account != address(0), "ACCOUNT is required");

        vm.startBroadcast(privKey);

        // Install the module
        address guardianAddr =
            EmailAccountRecovery(managerAddr).computeEmailAuthAddress(account, accountSalt);
        console.log("Guardian's EmailAuth address", guardianAddr);
        address[] memory guardians = new address[](1);
        guardians[0] = guardianAddr;
        uint256[] memory guardianWeights = new uint256[](1);
        guardianWeights[0] = 1;
        uint256 threshold = 1;
        uint256 delay = 0 seconds;
        uint256 expiry = 2 weeks;

        userOpCalldata = abi.encodeCall(
            IERC7579Account.installModule,
            (
                MODULE_TYPE_EXECUTOR,
                moduleAddr,
                abi.encode(
                    account,
                    isInstalledContext,
                    functionSelector,
                    guardians,
                    guardianWeights,
                    threshold,
                    delay,
                    expiry
                )
            )
        );

        // Install the module
        userOp =
            getDefaultUserOp(account, validator, Safe7579(safe7579));
        userOp.callData = userOpCalldata;
        userOp.signature = abi.encodePacked(
            uint48(0), uint48(type(uint48).max), hex"4141414141414141414141414141414141"
        );

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        console.log("install module userOps are ready");
        IEntryPoint(ENTRYPOINT_ADDR).handleOps{ gas: 3e6 }(userOps, payable(owner));
        vm.stopBroadcast();
    }

    function getNonce(address account, address validator) internal returns (uint256 nonce) {
        uint192 key = uint192(bytes24(bytes20(address(validator))));
        nonce = IEntryPoint(ENTRYPOINT_ADDR).getNonce(address(account), key);
    }

    function getDefaultUserOp(
        address account,
        address validator,
        Safe7579 safe7579
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        userOp = PackedUserOperation({
            sender: account,
            nonce: safe7579.getNonce(account, validator),
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(4e5), uint128(1e6))),
            preVerificationGas: 3e5,
            gasFees: bytes32(abi.encodePacked(uint128(0), uint128(0))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }
}
