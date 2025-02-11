// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Vm } from "forge-std/Vm.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeployEmailRecoveryModuleScript } from "../DeployEmailRecoveryModule.s.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract DeployEmailRecoveryModuleTest is BaseDeployTest {
    DeployEmailRecoveryModuleScript private target;

    function setUp() public override {
        super.setUp();
        envRecoveryFactory = deployRecoveryFactory();

        target = new DeployEmailRecoveryModuleScript();
    }

    function deployRecoveryFactory() internal returns (address) {
        EmailRecoveryFactory recoveryFactory =
            new EmailRecoveryFactory{ salt: bytes32(envCreate2Salt) }(envVerifier, envEmailAuthImpl);
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

    function test_NoValidatorEnv() public {
        setAllEnvVars();

        vm.setEnv("VALIDATOR", "");

        address validator = computeAddress(envCreate2Salt, type(OwnableValidator).creationCode, "");

        require(!isContractDeployed(validator), "validator should not be deployed yet");
        target.run();
        require(isContractDeployed(validator), "validator should be deployed");
    }

    function test_NoRecoveryFactoryEnv() public {
        setAllEnvVars();
        vm.setEnv("RECOVERY_FACTORY", "");

        address recoveryFactory = computeAddress(
            envCreate2Salt,
            type(EmailRecoveryFactory).creationCode,
            abi.encode(envVerifier, envEmailAuthImpl)
        );

        require(!isContractDeployed(recoveryFactory), "recovery factory should not be deployed yet");
        target.run();
        require(isContractDeployed(recoveryFactory), "recovery factory should be deployed");
    }

    function test_DeploymentEvent() public {
        setAllEnvVars();
        bytes memory eventSignature = "EmailRecoveryModuleDeployed(address,address,address,bytes4)";
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
            type(EmailRecoveryModule).creationCode,
            abi.encode(
                envVerifier,
                envDkimRegistry,
                envEmailAuthImpl,
                expectedCommandHandler,
                envMinimumDelay,
                envKillSwitchAuthorizer,
                envValidator,
                bytes4(keccak256(bytes("changeOwner(address)")))
            ),
            envRecoveryFactory
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
