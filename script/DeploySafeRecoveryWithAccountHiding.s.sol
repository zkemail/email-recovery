// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

// 1. `source .env`
// 2. `forge script
// script/DeploySafeRecoveryWithAccountHiding.s.sol:DeploySafeRecoveryWithAccountHiding_Script
// --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`
contract DeploySafeRecoveryWithAccountHidingScript is BaseDeployScript {
    uint256 private privateKey;
    uint256 private salt;
    uint256 private dkimDelay;
    uint256 private minimumDelay;
    address private killSwitchAuthorizer;
    address private dkimSigner;

    address public verifier;
    address public dkimRegistry;
    address public emailAuthImpl;

    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    function loadEnvVars() private {
        // revert if these are not set
        privateKey = vm.envUint("PRIVATE_KEY");
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        // default to uint256(0) if not set
        salt = vm.envOr("CREATE2_SALT", uint256(0));
        dkimDelay = vm.envOr("DKIM_DELAY", uint256(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));

        // default to address(0) if not set
        dkimSigner = vm.envOr("DKIM_SIGNER", address(0));
        verifier = vm.envOr("VERIFIER", address(0));
        dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));

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
            verifier = deployVerifier(initialOwner, salt);
        }

        if (dkimRegistry == address(0)) {
            dkimRegistry =
                deployUserOverrideableDKIMRegistry(initialOwner, dkimSigner, dkimDelay, salt);
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        EmailRecoveryUniversalFactory factory =
            new EmailRecoveryUniversalFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl);
        (emailRecoveryModule, emailRecoveryHandler) = factory.deployUniversalEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(AccountHidingRecoveryCommandHandler).creationCode,
            minimumDelay,
            killSwitchAuthorizer,
            dkimRegistry
        );

        console.log("Deployed Email Recovery Module at  ", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Handler at ", vm.toString(emailRecoveryHandler));

        vm.stopBroadcast();
    }
}
