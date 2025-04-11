// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import {console} from "forge-std/console.sol";
import {BaseDeployScript} from "script/base/BaseDeploy.s.sol";
import {EmailRecoveryCommandHandler} from "src/handlers/EmailRecoveryCommandHandler.sol";
import {EmailRecoveryFactory} from "src/factories/EmailRecoveryFactory.sol";
import {OwnableValidator} from "src/test/OwnableValidator.sol";

abstract contract BaseDeployEmailGuardianVerifier is BaseDeployScript {
    function deployValidator() private returns (address validator) {
        validator = address(new OwnableValidator{salt: config.create2Salt}());
        console.log("Deployed Ownable Validator at", validator);
    }

    function deployRecoveryFactory() private returns (address recoveryFactory) {
        recoveryFactory = address(
            new EmailRecoveryFactory{salt: config.create2Salt}()
        );
        console.log("Deployed Email Recovery Factory at", recoveryFactory);
    }

    function deploy() internal override {
        super.deploy();

        if (config.validator == address(0))
            config.validator = deployValidator();
        if (config.recoveryFactory == address(0))
            config.recoveryFactory = deployRecoveryFactory();

        (emailRecoveryModule) = EmailRecoveryFactory(config.recoveryFactory)
            .deployEmailRecoveryModule(
                config.create2Salt,
                config.minimumDelay,
                config.killSwitchAuthorizer,
                config.validator,
                bytes4(keccak256(bytes("changeOwner(address)")))
            );

        console.log(
            "Deployed Email Recovery Module at",
            vm.toString(emailRecoveryModule)
        );
    }
}
