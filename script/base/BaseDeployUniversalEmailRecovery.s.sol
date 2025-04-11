// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import {console} from "forge-std/console.sol";
import {BaseDeployScript} from "script/base/BaseDeploy.s.sol";
import {EmailRecoveryUniversalFactory} from "src/factories/EmailRecoveryUniversalFactory.sol";

abstract contract BaseDeployUniversalEmailRecoveryScript is BaseDeployScript {
    function getCommandHandlerBytecode()
        internal
        pure
        virtual
        returns (bytes memory);

    function deployRecoveryFactory() private returns (address recoveryFactory) {
        recoveryFactory = address(
            new EmailRecoveryUniversalFactory{salt: config.create2Salt}()
        );
        console.log("Deployed Email Recovery Factory at", recoveryFactory);
    }

    function deploy() internal override {
        super.deploy();

        if (config.recoveryFactory == address(0))
            config.recoveryFactory = deployRecoveryFactory();

        (emailRecoveryModule) = EmailRecoveryUniversalFactory(
            config.recoveryFactory
        ).deployUniversalEmailRecoveryModule(
                config.create2Salt,
                config.minimumDelay,
                config.killSwitchAuthorizer
            );

        console.log(
            "Deployed Email Recovery Module at",
            vm.toString(emailRecoveryModule)
        );
    }
}
