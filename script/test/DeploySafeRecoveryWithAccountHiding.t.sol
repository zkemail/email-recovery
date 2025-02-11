// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Vm } from "forge-std/Vm.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeploySafeRecoveryWithAccountHidingScript } from
    "../DeploySafeRecoveryWithAccountHiding.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract DeploySafeRecoveryWithAccountHidingTest is BaseDeployTest {
    DeploySafeRecoveryWithAccountHidingScript private target;

    function setUp() public override {
        super.setUp();
        target = new DeploySafeRecoveryWithAccountHidingScript();
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

    function test_DeploymentEvent() public {
        setAllEnvVars();
        bytes memory eventSignature = "UniversalEmailRecoveryModuleDeployed(address,address)";
        commonTest_DeploymentEvent(target, eventSignature);
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedRecoveryFactory = computeAddress(
            envCreate2Salt,
            type(EmailRecoveryUniversalFactory).creationCode,
            abi.encode(envVerifier, envEmailAuthImpl)
        );

        uint256 commandHandlerSalt = envCreate2Salt;
        address expectedCommandHandler = computeAddress(
            commandHandlerSalt,
            type(AccountHidingRecoveryCommandHandler).creationCode,
            "",
            expectedRecoveryFactory
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
            expectedRecoveryFactory
        );

        require(!isContractDeployed(expectedCommandHandler), "handler should not be deployed yet");
        require(!isContractDeployed(expectedRecoveryModule), "module should not be deployed yet");
        target.run();
        require(isContractDeployed(expectedCommandHandler), "handler should be deployed");
        require(isContractDeployed(expectedRecoveryModule), "module should be deployed");
        // also checking returned addresses
        require(target.emailRecoveryHandler() == expectedCommandHandler, "handler address mismatch");
        require(target.emailRecoveryModule() == expectedRecoveryModule, "module address mismatch");
    }
}
