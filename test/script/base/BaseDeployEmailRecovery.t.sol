// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployTest } from "test/script/base/BaseDeploy.t.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

abstract contract BaseDeployEmailRecoveryTest is BaseDeployTest {
    function setUp() public virtual override {
        super.setUp();
        config.recoveryFactory = deployRecoveryFactory();
    }

    function deployRecoveryFactory() internal returns (address) {
        EmailRecoveryFactory recoveryFactory = new EmailRecoveryFactory{ salt: config.create2Salt }(
            config.verifier, config.emailAuthImpl
        );
        return address(recoveryFactory);
    }

    // ### TEST CASES ###

    function test_NoVerifierEnv() public {
        commonTest_NoVerifierEnv();
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
        bytes memory eventSignature = "EmailRecoveryModuleDeployed(address,address,address,bytes4)";
        commonTest_DeploymentEvent(eventSignature);
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
