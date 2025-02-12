// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract BaseDeployUniversalScript is BaseDeployScript {
    error MissingRequiredParameter(string param);
    error InvalidCommandHandlerType();

    struct DeploymentConfig {
        bytes32 create2Salt;
        uint256 dkimDelay;
        uint256 minimumDelay;
        uint256 privateKey;
        address dkimRegistry;
        address dkimSigner;
        address emailAuthImpl;
        address killSwitchAuthorizer;
        address recoveryFactory;
        address verifier;
    }

    DeploymentConfig public config;

    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    function loadConfig() public {
        config = DeploymentConfig({
            create2Salt: bytes32(vm.envOr("CREATE2_SALT", uint256(0))),
            dkimDelay: vm.envOr("DKIM_DELAY", uint256(0)),
            minimumDelay: vm.envOr("MINIMUM_DELAY", uint256(0)),
            privateKey: vm.envOr("PRIVATE_KEY", uint256(0)),
            dkimRegistry: vm.envOr("DKIM_REGISTRY", address(0)),
            dkimSigner: vm.envOr("DKIM_SIGNER", address(0)),
            emailAuthImpl: vm.envOr("EMAIL_AUTH_IMPL", address(0)),
            killSwitchAuthorizer: vm.envOr("KILL_SWITCH_AUTHORIZER", address(0)),
            recoveryFactory: vm.envOr("RECOVERY_FACTORY", address(0)),
            verifier: vm.envOr("VERIFIER", address(0))
        });
    }

    function validateConfig() public view {
        if (config.privateKey == 0) {
            revert MissingRequiredParameter("PRIVATE_KEY");
        }

        if (config.killSwitchAuthorizer == address(0)) {
            revert MissingRequiredParameter("KILL_SWITCH_AUTHORIZER");
        }

        if (config.dkimRegistry == address(0) && config.dkimSigner == address(0)) {
            revert MissingRequiredParameter("DKIM_REGISTRY/DKIM_SIGNER");
        }
    }

    enum CommandHandlerType {
        AccountHidingRecovery,
        EmailRecovery,
        SafeRecovery
    }

    function getCommandHandlerBytecode(CommandHandlerType commandHandlerType)
        public
        pure
        returns (bytes memory)
    {
        if (commandHandlerType == CommandHandlerType.AccountHidingRecovery) {
            return type(AccountHidingRecoveryCommandHandler).creationCode;
        } else if (commandHandlerType == CommandHandlerType.EmailRecovery) {
            return type(EmailRecoveryCommandHandler).creationCode;
        } else if (commandHandlerType == CommandHandlerType.SafeRecovery) {
            return type(SafeRecoveryCommandHandler).creationCode;
        } else {
            revert InvalidCommandHandlerType();
        }
    }

    function deployUniversalEmailRecovery(CommandHandlerType commandHandlerType) public {
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

        if (config.recoveryFactory == address(0)) {
            config.recoveryFactory = address(
                new EmailRecoveryUniversalFactory{ salt: config.create2Salt }(
                    config.verifier, config.emailAuthImpl
                )
            );
            console.log("Deployed Email Recovery Factory at", config.recoveryFactory);
        }

        EmailRecoveryUniversalFactory factory =
            EmailRecoveryUniversalFactory(config.recoveryFactory);
        (emailRecoveryModule, emailRecoveryHandler) = factory.deployUniversalEmailRecoveryModule(
            config.create2Salt,
            config.create2Salt,
            getCommandHandlerBytecode(commandHandlerType),
            config.minimumDelay,
            config.killSwitchAuthorizer,
            config.dkimRegistry
        );

        console.log("Deployed Email Recovery Module at", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Handler at", vm.toString(emailRecoveryHandler));
    }

    function run() public virtual override {
        super.run();

        loadConfig();
        validateConfig();
    }
}
