// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeploy.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

abstract contract BaseDeployEmailRecoveryScript is BaseDeployScript {
    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    function deployEmailRecoveryModule() public {
        address initialOwner = vm.addr(config.privateKey);

        if (config.verifier == address(0)) {
            config.verifier = deployVerifier(initialOwner, config.create2Salt);
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

        if (config.validator == address(0)) {
            config.validator = address(new OwnableValidator{ salt: config.create2Salt }());
            console.log("Deployed Ownable Validator at", config.validator);
        }

        if (config.recoveryFactory == address(0)) {
            config.recoveryFactory = address(
                new EmailRecoveryFactory{ salt: config.create2Salt }(
                    config.verifier, config.emailAuthImpl
                )
            );
            console.log("Deployed Email Recovery Factory at", config.recoveryFactory);
        }

        (emailRecoveryModule, emailRecoveryHandler) = EmailRecoveryFactory(config.recoveryFactory)
            .deployEmailRecoveryModule(
            config.create2Salt,
            config.create2Salt,
            type(EmailRecoveryCommandHandler).creationCode,
            config.minimumDelay,
            config.killSwitchAuthorizer,
            config.dkimRegistry,
            config.validator,
            bytes4(keccak256(bytes("changeOwner(address)")))
        );

        console.log("Deployed Email Recovery Module at", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Handler at", vm.toString(emailRecoveryHandler));
    }
}
