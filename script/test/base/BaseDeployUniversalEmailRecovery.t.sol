// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployTest } from "./BaseDeploy.t.sol";
import { BaseDeployUniversalEmailRecoveryScript } from
    "../../base/BaseDeployUniversalEmailRecovery.s.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

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

    function commonTest_NoRecoveryFactoryEnv(BaseDeployUniversalEmailRecoveryScript target)
        public
    {
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

    function commonTest_DeploymentEvent(BaseDeployUniversalEmailRecoveryScript target) public {
        bytes memory eventSignature = "UniversalEmailRecoveryModuleDeployed(address,address)";
        commonTest_DeploymentEvent(target, eventSignature);
    }
}
