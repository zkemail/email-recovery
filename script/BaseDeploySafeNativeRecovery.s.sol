// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeploy.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

contract BaseDeploySafeNativeRecoveryScript is BaseDeployScript {
    address public emailRecoveryModule;

    function deploySafeNativeRecovery(CommandHandlerType commandHandlerType) public {
        address initialOwner = vm.addr(config.privateKey);

        if (config.zkVerifier == address(0)) {
            config.zkVerifier = deployVerifier(initialOwner, config.create2Salt);
        }

        if (config.dkimRegistry == address(0)) {
            config.dkimRegistry = deployUserOverrideableDKIMRegistry(
                initialOwner, config.dkimSigner, config.dkimDelay, config.create2Salt
            );
        }

        if (config.emailAuthImpl == address(0)) {
            config.emailAuthImpl = address(new EmailAuth{ salt: config.create2Salt }());
            console.log("Deployed Email Auth at", config.emailAuthImpl);
        }

        if (config.commandHandler == address(0)) {
            if (commandHandlerType == CommandHandlerType.AccountHidingRecovery) {
                config.commandHandler =
                    address(new AccountHidingRecoveryCommandHandler{ salt: config.create2Salt }());
            } else if (commandHandlerType == CommandHandlerType.SafeRecovery) {
                config.commandHandler =
                    address(new SafeRecoveryCommandHandler{ salt: config.create2Salt }());
            } else {
                revert InvalidCommandHandlerType();
            }
            console.log("Deployed Command Handler at", config.commandHandler);
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
