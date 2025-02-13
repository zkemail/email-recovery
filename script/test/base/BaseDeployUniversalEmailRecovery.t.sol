// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployTest } from "./BaseDeploy.t.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

abstract contract BaseDeployUniversalEmailRecoveryTest is BaseDeployTest {
    function setUp() public virtual override {
        super.setUp();
        config.recoveryFactory = deployRecoveryUniversalFactory();
    }

    function deployRecoveryUniversalFactory() internal returns (address) {
        EmailRecoveryUniversalFactory recoveryFactory = new EmailRecoveryUniversalFactory{
            salt: config.create2Salt
        }(config.verifier, config.emailAuthImpl);
        return address(recoveryFactory);
    }

    function getCommandHandlerBytecode() internal pure virtual returns (bytes memory);

    function test_NoVerifierEnv() public {
        commonTest_NoVerifierEnv();
    }

    function test_NoDkimRegistryEnv() public {
        commonTest_NoDkimRegistryEnv();
    }

    function test_NoEmailAuthImplEnv() public {
        commonTest_NoEmailAuthImplEnv();
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
        bytes memory eventSignature = "UniversalEmailRecoveryModuleDeployed(address,address)";
        commonTest_DeploymentEvent(eventSignature);
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedCommandHandler = computeAddress(
            config.create2Salt, getCommandHandlerBytecode(), "", config.recoveryFactory
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
