// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployEmailRecoveryTest } from "./base/BaseDeployEmailRecovery.t.sol";
import { DeployEmailRecoveryScript } from "../DeployEmailRecovery.s.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract DeployEmailRecoveryModuleTest is BaseDeployEmailRecoveryTest {
    DeployEmailRecoveryScript private target;

    function setUp() public override {
        super.setUp();
        target = new DeployEmailRecoveryScript();
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

    function test_NoVerifierEnv() public {
        commonTest_NoVerifierEnv(target);
    }

    function test_NoDkimRegistryEnv() public {
        commonTest_NoDkimRegistryEnv(target);
    }

    function test_NoEmailAuthImplEnv() public {
        commonTest_NoEmailAuthImplEnv(target);
    }

    function test_NoValidatorEnv() public {
        commonTest_NoValidatorEnv(target);
    }

    function test_NoRecoveryFactoryEnv() public {
        commonTest_NoRecoveryFactoryEnv(target);
    }

    function test_DeploymentEvent() public {
        commonTest_DeploymentEvent(target);
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedCommandHandler = computeAddress(
            config.create2Salt,
            type(EmailRecoveryCommandHandler).creationCode,
            "",
            config.recoveryFactory
        );

        address expectedRecoveryModule = computeAddress(
            config.create2Salt,
            type(EmailRecoveryModule).creationCode,
            abi.encode(
                config.verifier,
                config.dkimRegistry,
                config.emailAuthImpl,
                expectedCommandHandler,
                config.minimumDelay,
                config.killSwitchAuthorizer,
                config.validator,
                bytes4(keccak256(bytes("changeOwner(address)")))
            ),
            config.recoveryFactory
        );

        assert(!isContractDeployed(expectedCommandHandler));
        assert(!isContractDeployed(expectedRecoveryModule));
        target.run();
        assert(isContractDeployed(expectedCommandHandler));
        assert(isContractDeployed(expectedRecoveryModule));
        // also checking returned addresses
        assertEq(target.emailRecoveryHandler(), expectedCommandHandler);
        assertEq(target.emailRecoveryModule(), expectedRecoveryModule);
    }
}
