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
    bytes32 internal create2Salt;

    uint256 internal dkimDelay;
    uint256 internal minimumDelay;
    uint256 internal privateKey;

    address internal dkimRegistry;
    address internal dkimSigner;
    address internal emailAuthImpl;
    address internal killSwitchAuthorizer;
    address internal recoveryFactory;
    address internal verifier;
    address internal initialOwner;

    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    // using defaults for all vars, checking required vars later
    function loadEnvVars() internal {
        create2Salt = bytes32(vm.envOr("CREATE2_SALT", uint256(0)));

        dkimDelay = vm.envOr("DKIM_DELAY", uint256(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        privateKey = vm.envOr("PRIVATE_KEY", uint256(0));

        dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        dkimSigner = vm.envOr("DKIM_SIGNER", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        killSwitchAuthorizer = vm.envOr("KILL_SWITCH_AUTHORIZER", address(0));
        recoveryFactory = vm.envOr("RECOVERY_FACTORY", address(0));
        verifier = vm.envOr("VERIFIER", address(0));
    }

    function checkRequiredVars() internal view {
        if (privateKey == 0) {
            console.log("PRIVATE_KEY is required");
            revert("PRIVATE_KEY is required");
        }

        if (killSwitchAuthorizer == address(0)) {
            console.log("KILL_SWITCH_AUTHORIZER is required");
            revert("KILL_SWITCH_AUTHORIZER is required");
        }

        if (dkimRegistry == address(0) && dkimSigner == address(0)) {
            console.log("DKIM_SIGNER or DKIM_REGISTRY is required");
            revert("DKIM_SIGNER or DKIM_REGISTRY is required");
        }
    }

    enum CommandHandlerType {
        AccountHidingRecovery,
        EmailRecovery,
        SafeRecovery
    }

    function getCommandHandlerBytecode(CommandHandlerType commandHandlerType)
        internal
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
            console.log("Invalid CommandHandlerType");
            revert("Invalid CommandHandlerType");
        }
    }

    function deployUniversalEmailRecovery(CommandHandlerType commandHandlerType) internal {
        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, create2Salt);
        }

        if (dkimRegistry == address(0)) {
            dkimRegistry =
                deployUserOverrideableDKIMRegistry(initialOwner, dkimSigner, dkimDelay, create2Salt);
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(create2Salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        if (recoveryFactory == address(0)) {
            recoveryFactory = address(
                new EmailRecoveryUniversalFactory{ salt: bytes32(create2Salt) }(
                    verifier, emailAuthImpl
                )
            );
            console.log("Deployed Email Recovery Factory at", recoveryFactory);
        }

        EmailRecoveryUniversalFactory factory = EmailRecoveryUniversalFactory(recoveryFactory);
        (emailRecoveryModule, emailRecoveryHandler) = factory.deployUniversalEmailRecoveryModule(
            create2Salt,
            create2Salt,
            getCommandHandlerBytecode(commandHandlerType),
            minimumDelay,
            killSwitchAuthorizer,
            dkimRegistry
        );

        console.log("Deployed Email Recovery Module at", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Handler at", vm.toString(emailRecoveryHandler));
    }

    function run() public virtual override {
        super.run();

        loadEnvVars();
        checkRequiredVars();
        initialOwner = vm.addr(privateKey);
    }
}
