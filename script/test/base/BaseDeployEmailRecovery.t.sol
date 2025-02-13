// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployTest } from "./BaseDeploy.t.sol";
import { BaseDeployEmailRecoveryScript } from "../../base/BaseDeployEmailRecovery.s.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

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

    function commonTest_NoValidatorEnv(BaseDeployEmailRecoveryScript target) public {
        setAllEnvVars();

        vm.setEnv("VALIDATOR", "");

        address validator =
            computeAddress(config.create2Salt, type(OwnableValidator).creationCode, "");

        assert(!isContractDeployed(validator));
        target.run();
        assert(isContractDeployed(validator));
    }

    function commonTest_NoRecoveryFactoryEnv(BaseDeployEmailRecoveryScript target) public {
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

    function commonTest_DeploymentEvent(BaseDeployEmailRecoveryScript target) public {
        bytes memory eventSignature = "EmailRecoveryModuleDeployed(address,address,address,bytes4)";
        commonTest_DeploymentEvent(target, eventSignature);
    }
}
