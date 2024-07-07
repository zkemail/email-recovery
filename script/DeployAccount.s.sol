// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Safe7579 } from "safe7579/Safe7579.sol";
import { Safe7579Launchpad, IERC7484 } from "safe7579/Safe7579Launchpad.sol";
import { ISafe7579 } from "safe7579/ISafe7579.sol";
import { ModuleManager } from "erc7579/core/ModuleManager.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { MockRegistry, MockTarget, MockValidator } from "modulekit/Mocks.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { SafeProxyFactory } from
    "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { Solarray } from "solarray/Solarray.sol";
import { PackedUserOperation } from "erc7579-implementation/src/interfaces/IERC4337Account.sol";
import { ModuleInit } from "safe7579/DataTypes.sol";
import { IEntryPoint, ENTRYPOINT_ADDR } from "modulekit/test/predeploy/EntryPoint.sol";
import "forge-std/console2.sol";

contract DeployAccountScript is Script {
    uint256 privKey;
    address owner;

    address predict;
    bytes32 salt;

    IERC7484 registry;
    address payable safe7579;
    address singleton;
    address payable launchpad;
    address validator;
    address safeProxyFactory;
    address mockTarget;

    function run() public {
        privKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privKey);

        owner = vm.envAddress("SIGNER");
        require(owner != address(0), "SIGNER is required");
        address[] memory owners = new address[](1);
        owners[0] = owner;

        address registryAddr = vm.envOr("REGISTRY", address(0));
        if (registryAddr == address(0)) {
            registryAddr = address(new MockRegistry());
        }
        registry = IERC7484(registryAddr);

        safe7579 = payable(vm.envOr("SAFE_7579", address(0)));
        if (safe7579 == address(0)) {
            safe7579 = payable(address(new Safe7579()));
        }

        singleton = vm.envOr("SAFE", address(0));
        if (singleton == address(0)) {
            singleton = address(new Safe());
        }

        launchpad = payable(vm.envOr("VALIDATOR", address(0)));
        if (launchpad == address(0)) {
            launchpad = payable(address(new Safe7579Launchpad(ENTRYPOINT_ADDR, registry)));
        }

        validator = vm.envOr("SAFE_7579_LAUNCHPAD", address(0));
        if (validator == address(0)) {
            validator = address(new MockValidator());
        }

        safeProxyFactory = vm.envOr("SAFE_PROXY_FACTORY", address(0));
        if (safeProxyFactory == address(0)) {
            safeProxyFactory = address(new SafeProxyFactory());
        }

        mockTarget = vm.envOr("MOCK_TARGET", address(0));
        if (mockTarget == address(0)) {
            mockTarget = address(new MockTarget());
        }

        ModuleInit[] memory validators = new ModuleInit[](1);
        validators[0] = ModuleInit({ module: validator, initData: bytes("") });
        ModuleInit[] memory executors = new ModuleInit[](0);
        ModuleInit[] memory fallbacks = new ModuleInit[](0);
        ModuleInit[] memory hooks = new ModuleInit[](0);

        Safe7579Launchpad.InitData memory initData = Safe7579Launchpad.InitData({
            singleton: singleton,
            owners: owners,
            threshold: 1,
            setupTo: launchpad,
            setupData: abi.encodeCall(
                Safe7579Launchpad.initSafe7579,
                (
                    safe7579,
                    executors,
                    fallbacks,
                    hooks,
                    Solarray.addresses(address(0xF7C012789aac54B5E33EA5b88064ca1F1172De05)),
                    1
                )
            ),
            safe7579: ISafe7579(safe7579),
            validators: validators,
            callData: abi.encodeCall(
                IERC7579Account.execute,
                (
                    ModeLib.encodeSimpleSingle(),
                    ExecutionLib.encodeSingle({
                        target: mockTarget,
                        value: 0,
                        callData: abi.encodeCall(MockTarget.set, (1337))
                    })
                )
            )
        });

        bytes32 initHash = Safe7579Launchpad(launchpad).hash(initData);

        bytes memory factoryInitializer =
            abi.encodeCall(Safe7579Launchpad.preValidationSetup, (initHash, address(0), ""));

        PackedUserOperation memory userOp =
            getDefaultUserOp(address(0), validator, Safe7579(safe7579));

        salt = bytes32(uint256(1));
        {
            userOp.callData = abi.encodeCall(Safe7579Launchpad.setupSafe, (initData));
            userOp.initCode = _initCode(factoryInitializer, salt, safeProxyFactory, launchpad);

            predict = Safe7579Launchpad(launchpad).predictSafeAddress({
                singleton: launchpad,
                safeProxyFactory: safeProxyFactory,
                creationCode: SafeProxyFactory(safeProxyFactory).proxyCreationCode(),
                salt: salt,
                factoryInitializer: factoryInitializer
            });
            userOp.sender = predict;
            userOp.signature = abi.encodePacked(
                uint48(0), uint48(type(uint48).max), hex"4141414141414141414141414141414141"
            );
        }

        IEntryPoint entryPoint = IEntryPoint(ENTRYPOINT_ADDR);

        bytes32 userOpHash = entryPoint.getUserOpHash(userOp);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;

        {
            console.log("Deployed MockRegistry at", registryAddr);
            console.log("Deployed Safe7579 at", safe7579);
            console.log("Deployed Safe at", singleton);
            console.log("Deployed Safe7579Launchpad at", launchpad);
            console.log("Deployed MockValidator at", validator);
            console.log("Deployed SafeProxyFactory at", safeProxyFactory);
            console.log("Deployed MockTarget at", mockTarget);
            console.log("Deployed Safe account at", predict);

            uint256 amount = 0.01 ether;
            (bool success,) = predict.call{ value: amount }("");
            // send eth to userOp sender

            entryPoint.handleOps(userOps, payable(owner));
            vm.stopBroadcast();
        }
    }

    function _initCode(
        bytes memory initializer,
        bytes32 salt,
        address safeProxyFactory,
        address launchpad
    )
        internal
        view
        returns (bytes memory _initCode)
    {
        _initCode = abi.encodePacked(
            address(safeProxyFactory),
            abi.encodeCall(
                SafeProxyFactory.createProxyWithNonce,
                (address(launchpad), initializer, uint256(salt))
            )
        );
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
            accountGasLimits: bytes32(
                0x00000000000000000000000000060e7400000000000000000000000000051d3c
            ),
            preVerificationGas: 69_660,
            gasFees: bytes32(0x0000000000000000000000005241210000000000000000000000000ca36194f7),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }
}
