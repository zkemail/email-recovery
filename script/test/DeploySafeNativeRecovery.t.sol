// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeRecoveryTest } from "./base/BaseDeploySafeNativeRecovery.t.sol";
import { DeploySafeNativeRecoveryScript } from "../DeploySafeNativeRecovery.s.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract DeploySafeNativeRecoveryTest is BaseDeploySafeNativeRecoveryTest {
    DeploySafeNativeRecoveryScript private target;

    function setUp() public override {
        super.setUp();
        config.zkVerifier = deployVerifier(vm.addr(config.privateKey));
        config.commandHandler = deploySafeRecoveryCommandHandler(config.create2Salt);

        target = new DeploySafeNativeRecoveryScript();
    }

    function setAllEnvVars() internal override {
        super.setAllEnvVars();

        vm.setEnv("ZK_VERIFIER", vm.toString(config.zkVerifier));
        vm.setEnv("COMMAND_HANDLER", vm.toString(config.commandHandler));
    }

    function deploySafeRecoveryCommandHandler(bytes32 salt) internal returns (address) {
        return address(new SafeRecoveryCommandHandler{ salt: bytes32(salt) }());
    }

    function test_RevertIf_NoPrivateKeyEnv() public {
        setAllEnvVars();
        commonTest_RevertIf_NoPrivateKeyEnv(target);
    }

    function test_RevertIf_NoKillSwitchAuthorizerEnv() public {
        setAllEnvVars();
        commonTest_RevertIf_NoKillSwitchAuthorizerEnv(target);
    }

    function test_RevertIf_NoDkimRegistryAndSignerEnvs() public {
        setAllEnvVars();
        commonTest_RevertIf_NoDkimRegistryAndSignerEnvs(target);
    }

    function test_NoZkVerifierEnv() public {
        setAllEnvVars();
        commonTest_NoZkVerifierEnv(target);
    }

    function test_NoDkimRegistryEnv() public {
        setAllEnvVars();
        commonTest_NoDkimRegistryEnv(target);
    }

    function test_NoEmailAuthImplEnv() public {
        setAllEnvVars();
        commonTest_NoEmailAuthImplEnv(target);
    }

    function test_NoCommandHandlerEnv() public {
        setAllEnvVars();
        vm.setEnv("COMMAND_HANDLER", "");

        address handler =
            computeAddress(config.create2Salt, type(SafeRecoveryCommandHandler).creationCode, "");

        assert(!isContractDeployed(handler));
        target.run();
        assert(isContractDeployed(handler));
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedModuleAddress = computeAddress(
            config.create2Salt,
            type(SafeEmailRecoveryModule).creationCode,
            abi.encode(
                config.zkVerifier,
                config.dkimRegistry,
                config.emailAuthImpl,
                config.commandHandler,
                config.minimumDelay,
                config.killSwitchAuthorizer
            )
        );

        assert(!isContractDeployed(expectedModuleAddress));
        target.run();
        assert(isContractDeployed(expectedModuleAddress));
        // also checking returned address
        assertEq(target.emailRecoveryModule(), expectedModuleAddress);
    }
}
