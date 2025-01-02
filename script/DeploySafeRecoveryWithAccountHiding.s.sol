// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";

import { BaseDeployScript } from "./BaseDeployScript.s.sol";

// 1. `source .env`
// 2. `forge script
// script/DeploySafeRecoveryWithAccountHiding.s.sol:DeploySafeRecoveryWithAccountHiding_Script
// --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`
contract DeploySafeRecoveryWithAccountHiding_Script is BaseDeployScript {
    address verifier;
    address dkim;
    address dkimRegistrySigner;
    address emailAuthImpl;
    uint256 minimumDelay;
    address killSwitchAuthorizer;

    address initialOwner;
    uint256 salt;

    function run() public override {
        super.run();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        verifier = vm.envOr("VERIFIER", address(0));
        dkim = vm.envOr("DKIM_REGISTRY", address(0));
        dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        salt = vm.envOr("CREATE2_SALT", uint256(0));

        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, salt);
        }

        // Deploy Useroverridable DKIM registry
        dkim = vm.envOr("DKIM_REGISTRY", address(0));
        uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
        if (dkim == address(0)) {
            dkim = deployUserOverrideableDKIMRegistry(
                initialOwner, dkimRegistrySigner, setTimeDelay, salt
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        EmailRecoveryUniversalFactory factory =
            new EmailRecoveryUniversalFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl);
        (address module, address commandHandler) = factory.deployUniversalEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(AccountHidingRecoveryCommandHandler).creationCode,
            minimumDelay,
            killSwitchAuthorizer,
            dkim
        );

        console.log("Deployed Email Recovery Module at  ", vm.toString(module));
        console.log("Deployed Email Recovery Handler at ", vm.toString(commandHandler));

        vm.stopBroadcast();
    }
}
