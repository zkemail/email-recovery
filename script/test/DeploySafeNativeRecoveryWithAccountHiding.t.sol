// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeRecoveryTest } from "./base/BaseDeploySafeNativeRecovery.t.sol";
import { DeploySafeNativeRecoveryWithAccountHidingScript } from
    "../DeploySafeNativeRecoveryWithAccountHiding.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

contract DeploySafeNativeRecoveryWithAccountHidingTest is BaseDeploySafeNativeRecoveryTest {
    DeploySafeNativeRecoveryWithAccountHidingScript private target;

    function setUp() public override {
        super.setUp();
        config.zkVerifier = deployVerifier(vm.addr(config.privateKey));
        config.commandHandler = deployAccountHidingRecoveryCommandHandler(config.create2Salt);

        target = new DeploySafeNativeRecoveryWithAccountHidingScript();
    }

    function setAllEnvVars() internal override {
        super.setAllEnvVars();

        vm.setEnv("ZK_VERIFIER", vm.toString(config.zkVerifier));
        vm.setEnv("COMMAND_HANDLER", vm.toString(config.commandHandler));
    }

    function deployAccountHidingRecoveryCommandHandler(bytes32 salt) internal returns (address) {
        return address(new AccountHidingRecoveryCommandHandler{ salt: bytes32(salt) }());
    }

    function test_RevertIf_NoPrivateKeyEnv() public {
        commonTest_RevertIf_NoPrivateKeyEnv(target);
    }

    function test_RevertIf_NoKillSwitchAuthorizerEnv() public {
        commonTest_RevertIf_NoKillSwitchAuthorizerEnv(target);
    }

    function test_RevertIf_NoDkimRegistryAndSignerEnvs() public {
        commonTest_RevertIf_NoDkimRegistryAndSignerEnvs(target);
    }

    function test_NoZkVerifierEnv() public {
        commonTest_NoZkVerifierEnv(target);
    }

    function test_NoDkimRegistryEnv() public {
        commonTest_NoDkimRegistryEnv(target);
    }

    function test_NoEmailAuthImplEnv() public {
        commonTest_NoEmailAuthImplEnv(target);
    }

    function test_NoCommandHandlerEnv() public {
        setAllEnvVars();
        vm.setEnv("COMMAND_HANDLER", "");

        address handler = computeAddress(
            config.create2Salt, type(AccountHidingRecoveryCommandHandler).creationCode, ""
        );

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
