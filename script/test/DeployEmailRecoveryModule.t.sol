// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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
        config.recoveryFactory = deployRecoveryFactory();

        target = new DeployEmailRecoveryModuleScript();
    }

    function deployRecoveryFactory() internal returns (address) {
        EmailRecoveryFactory recoveryFactory = new EmailRecoveryFactory{ salt: config.create2Salt }(
            config.verifier, config.emailAuthImpl
        );
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

        address validator =
            computeAddress(config.create2Salt, type(OwnableValidator).creationCode, "");

        assert(!isContractDeployed(validator));
        target.run();
        assert(isContractDeployed(validator));
    }

    function test_NoRecoveryFactoryEnv() public {
        setAllEnvVars();
        vm.setEnv("RECOVERY_FACTORY", "");

        address recoveryFactory = computeAddress(
            config.create2Salt,
            type(EmailRecoveryFactory).creationCode,
            abi.encode(config.verifier, config.emailAuthImpl)
        );

        assert(!isContractDeployed(recoveryFactory));
        target.run();
        assert(isContractDeployed(recoveryFactory));
    }

    function test_DeploymentEvent() public {
        setAllEnvVars();
        bytes memory eventSignature = "EmailRecoveryModuleDeployed(address,address,address,bytes4)";
        commonTest_DeploymentEvent(target, eventSignature);
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
