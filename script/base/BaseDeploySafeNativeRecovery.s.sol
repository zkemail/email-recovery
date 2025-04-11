// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import {console} from "forge-std/console.sol";
import {BaseDeployScript} from "script/base/BaseDeploy.s.sol";
import {SafeEmailRecoveryModule} from "src/modules/SafeEmailRecoveryModule.sol";

abstract contract BaseDeploySafeNativeRecoveryScript is BaseDeployScript {
    function deploy() internal override {
        super.deploy();

        emailRecoveryModule = address(
            new SafeEmailRecoveryModule{salt: config.create2Salt}(
                config.minimumDelay,
                config.killSwitchAuthorizer
            )
        );

        console.log(
            "Deployed Email Recovery Module at",
            vm.toString(emailRecoveryModule)
        );
    }
}
