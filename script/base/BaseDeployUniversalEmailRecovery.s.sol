// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeploy.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

abstract contract BaseDeployUniversalEmailRecoveryScript is BaseDeployScript {
    function getCommandHandlerBytecode() internal pure virtual returns (bytes memory);

    function deploy() internal override {
        super.deploy();

        address initialOwner = vm.addr(config.privateKey);

        if (config.verifier == address(0)) {
            config.verifier = deployVerifier(initialOwner, config.create2Salt);
        }

        if (config.recoveryFactory == address(0)) {
            config.recoveryFactory = address(
                new EmailRecoveryUniversalFactory{ salt: config.create2Salt }(
                    config.verifier, config.emailAuthImpl
                )
            );
            console.log("Deployed Email Recovery Factory at", config.recoveryFactory);
        }

        (emailRecoveryModule, emailRecoveryHandler) = EmailRecoveryUniversalFactory(
            config.recoveryFactory
        ).deployUniversalEmailRecoveryModule(
            config.create2Salt,
            config.create2Salt,
            getCommandHandlerBytecode(),
            config.minimumDelay,
            config.killSwitchAuthorizer,
            config.dkimRegistry
        );

        console.log("Deployed Email Recovery Module at", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Handler at", vm.toString(emailRecoveryHandler));
    }
}
