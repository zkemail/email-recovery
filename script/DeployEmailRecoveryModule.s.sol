// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract DeployEmailRecoveryModuleScript is BaseDeployScript {
    uint256 private privateKey;
    uint256 private create2Salt;
    uint256 private dkimDelay;
    uint256 private minimumDelay;
    address private killSwitchAuthorizer;
    address private dkimSigner;

    address public verifier;
    address public dkimRegistry;
    address public emailAuthImpl;
    address public validator;
    address public recoveryFactory;

    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    function loadEnvVars() private {
        // revert if not set
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
        validator = vm.envOr("VALIDATOR", address(0));
        recoveryFactory = vm.envOr("RECOVERY_FACTORY", address(0));

        // other reverts
        if (dkimRegistry == address(0)) {
            require(dkimSigner != address(0), "DKIM_REGISTRY or DKIM_SIGNER is required");
        }
    }

    function run() public override {
        super.run();

        loadEnvVars();
        vm.startBroadcast(privateKey);

        address initialOwner = vm.addr(privateKey);

        if (verifier == address(0)) {
            verifier = super.deployVerifier(initialOwner, create2Salt);
        }

        if (dkimRegistry == address(0)) {
            dkimRegistry = super.deployUserOverrideableDKIMRegistry(
                initialOwner, dkimSigner, dkimDelay, create2Salt
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(create2Salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        if (validator == address(0)) {
            validator = address(new OwnableValidator{ salt: bytes32(create2Salt) }());
            console.log("Deployed Ownable Validator at", validator);
        }

        if (recoveryFactory == address(0)) {
            recoveryFactory = address(
                new EmailRecoveryFactory{ salt: bytes32(create2Salt) }(verifier, emailAuthImpl)
            );
            console.log("Deployed Email Recovery Factory at", recoveryFactory);
        }

        EmailRecoveryFactory factory = EmailRecoveryFactory(recoveryFactory);
        (emailRecoveryModule, emailRecoveryHandler) = factory.deployEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(EmailRecoveryCommandHandler).creationCode,
            minimumDelay,
            killSwitchAuthorizer,
            dkimRegistry,
            validator,
            bytes4(keccak256(bytes("changeOwner(address)")))
        );

        console.log("Deployed Email Recovery Module at", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Handler at", vm.toString(emailRecoveryHandler));

        vm.stopBroadcast();
    }
}
