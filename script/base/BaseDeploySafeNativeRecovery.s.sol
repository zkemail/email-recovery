// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeploy.s.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

abstract contract BaseDeploySafeNativeRecoveryScript is BaseDeployScript {
    function deployZKVerifier() internal {
        address initialOwner = vm.addr(config.privateKey);
        config.zkVerifier = deployVerifier(initialOwner, config.create2Salt);
    }

    function deploy() internal override {
        super.deploy();

        if (config.zkVerifier == address(0)) deployZKVerifier();

        emailRecoveryModule = address(
            new SafeEmailRecoveryModule{ salt: config.create2Salt }(
                config.zkVerifier,
                config.dkimRegistry,
                config.emailAuthImpl,
                config.commandHandler,
                config.minimumDelay,
                config.killSwitchAuthorizer
            )
        );

        console.log("Deployed Email Recovery Module at", vm.toString(emailRecoveryModule));
    }
}
