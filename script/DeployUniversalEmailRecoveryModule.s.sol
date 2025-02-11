// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

contract DeployUniversalEmailRecoveryModuleScript is BaseDeployScript {
    uint256 private privateKey;
    uint256 private create2Salt;
    uint256 private dkimDelay;
    uint256 private minimumDelay;
    address private killSwitchAuthorizer;
    address private dkimSigner;

    address private verifier;
    address private dkimRegistry;
    address private emailAuthImpl;
    address private recoveryFactory;

    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    function loadEnvVars() private {
        // revert if these are not set
        privateKey = vm.envUint("PRIVATE_KEY");
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        // default to uint256(0) if not set
        create2Salt = vm.envOr("CREATE2_SALT", uint256(0));
        dkimDelay = vm.envOr("DKIM_DELAY", uint256(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));

        // default to address(0) if not set
        dkimSigner = vm.envOr("DKIM_SIGNER", address(0));
        verifier = vm.envOr("VERIFIER", address(0));
        dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        recoveryFactory = vm.envOr("RECOVERY_FACTORY", address(0));

        // other reverts
        if (dkimRegistry == address(0)) {
            // if DKIM_REGISTRY is not set, DKIM_SIGNER is required
            require(dkimSigner != address(0), "DKIM_SIGNER is required");
        }
    }

    function run() public override {
        super.run();

        loadEnvVars();
        vm.startBroadcast(privateKey);

        address initialOwner = vm.addr(privateKey);
        bytes32 commandHandlerSalt = bytes32(create2Salt);
        bytes32 recoveryModuleSalt = bytes32(create2Salt);

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
            commandHandlerSalt,
            recoveryModuleSalt,
            type(EmailRecoveryCommandHandler).creationCode,
            minimumDelay,
            killSwitchAuthorizer,
            dkimRegistry
        );

        console.log("Deployed Email Recovery Module at", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Handler at", vm.toString(emailRecoveryHandler));

        vm.stopBroadcast();
    }
}
