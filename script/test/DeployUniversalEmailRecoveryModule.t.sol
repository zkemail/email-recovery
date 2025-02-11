// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeployUniversalEmailRecoveryModuleScript } from
    "../DeployUniversalEmailRecoveryModule.s.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract DeployUniversalEmailRecoveryModuleTest is BaseDeployTest {
    DeployUniversalEmailRecoveryModuleScript private target;

    function setUp() public override {
        super.setUp();
        envRecoveryFactory = deployRecoveryUniversalFactory();

        target = new DeployUniversalEmailRecoveryModuleScript();
    }

    function deployRecoveryUniversalFactory() internal returns (address) {
        EmailRecoveryUniversalFactory recoveryFactory = new EmailRecoveryUniversalFactory{
            salt: bytes32(envCreate2Salt)
        }(envVerifier, envEmailAuthImpl);
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
            envCreate2Salt,
            type(EmailRecoveryUniversalFactory).creationCode,
            abi.encode(envVerifier, envEmailAuthImpl)
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

        uint256 commandHandlerSalt = envCreate2Salt;
        address expectedCommandHandler = computeAddress(
            commandHandlerSalt,
            type(EmailRecoveryCommandHandler).creationCode,
            "",
            envRecoveryFactory
        );

        uint256 recoveryModuleSalt = envCreate2Salt;
        address expectedRecoveryModule = computeAddress(
            recoveryModuleSalt,
            type(UniversalEmailRecoveryModule).creationCode,
            abi.encode(
                envVerifier,
                envDkimRegistry,
                envEmailAuthImpl,
                expectedCommandHandler,
                envMinimumDelay,
                envKillSwitchAuthorizer
            ),
            envRecoveryFactory
        );

        assert(!isContractDeployed(expectedCommandHandler)); // handler should not be deployed yet
        assert(!isContractDeployed(expectedRecoveryModule)); // module should not be deployed yet
        target.run();
        assert(isContractDeployed(expectedCommandHandler)); // handler should be deployed
        assert(isContractDeployed(expectedRecoveryModule)); // module should be deployed
        // also checking returned addresses
        assertEq(target.emailRecoveryHandler(), expectedCommandHandler); // handler address mismatch
        assertEq(target.emailRecoveryModule(), expectedRecoveryModule); // module address mismatch
    }
}
