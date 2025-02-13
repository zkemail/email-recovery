// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeploy.s.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

abstract contract BaseDeploySafeNativeRecoveryScript is BaseDeployScript {
    function deploy() internal override {
        super.deploy();

        address initialOwner = vm.addr(config.privateKey);

        if (config.zkVerifier == address(0)) {
            config.zkVerifier = deployVerifier(initialOwner, config.create2Salt);
        }

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
