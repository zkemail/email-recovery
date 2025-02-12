// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeploySafeRecoveryScript } from "../DeploySafeRecovery.s.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract DeploySafeRecoveryTest is BaseDeployTest {
    DeploySafeRecoveryScript private target;

    function setUp() public override {
        super.setUp();
        config.recoveryFactory = deployRecoveryUniversalFactory();

        target = new DeploySafeRecoveryScript();
    }

    function deployRecoveryUniversalFactory() internal returns (address) {
        EmailRecoveryUniversalFactory recoveryFactory = new EmailRecoveryUniversalFactory{
            salt: config.create2Salt
        }(config.verifier, config.emailAuthImpl);
        return address(recoveryFactory);
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

    function test_NoVerifierEnv() public {
        setAllEnvVars();
        commonTest_NoVerifierEnv(target);
    }

    function test_NoDkimRegistryEnv() public {
        setAllEnvVars();
        commonTest_NoDkimRegistryEnv(target);
    }

    function test_NoEmailAuthImplEnv() public {
        setAllEnvVars();
        commonTest_NoEmailAuthImplEnv(target);
    }

    function test_NoRecoveryFactoryEnv() public {
        setAllEnvVars();

        vm.setEnv("RECOVERY_FACTORY", "");

        address recoveryFactory = computeAddress(
            config.create2Salt,
            type(EmailRecoveryUniversalFactory).creationCode,
            abi.encode(config.verifier, config.emailAuthImpl)
        );

        assert(!isContractDeployed(recoveryFactory));
        target.run();
        assert(isContractDeployed(recoveryFactory));
    }

    function test_DeploymentEvent() public {
        setAllEnvVars();
        bytes memory eventSignature = "UniversalEmailRecoveryModuleDeployed(address,address)";
        commonTest_DeploymentEvent(target, eventSignature);
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedCommandHandler = computeAddress(
            config.create2Salt,
            type(SafeRecoveryCommandHandler).creationCode,
            "",
            config.recoveryFactory
        );

        address expectedRecoveryModule = computeAddress(
            config.create2Salt,
            type(UniversalEmailRecoveryModule).creationCode,
            abi.encode(
                config.verifier,
                config.dkimRegistry,
                config.emailAuthImpl,
                expectedCommandHandler,
                config.minimumDelay,
                config.killSwitchAuthorizer
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
