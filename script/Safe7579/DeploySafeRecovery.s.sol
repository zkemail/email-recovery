// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { BaseDeployScript } from "../BaseDeployScript.s.sol";

// 1. `source .env`
// 2. `forge script --chain sepolia script/DeploySafeRecovery.s.sol:DeploySafeRecovery_Script
// --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv`
contract DeploySafeRecovery_Script is BaseDeployScript {
    address verifier;
    address dkim;
    address emailAuthImpl;
    address commandHandler;
    uint256 minimumDelay;
    address killSwitchAuthorizer;

    address initialOwner;
    address dkimRegistrySigner;
    uint256 dkimDelay;
    uint256 salt;

    function run() public override {
        super.run();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        verifier = vm.envOr("VERIFIER", address(0));
        dkim = vm.envOr("DKIM_REGISTRY", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        commandHandler = vm.envOr("COMMAND_HANDLER", address(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        dkimDelay = vm.envOr("DKIM_DELAY", uint256(0));
        salt = vm.envOr("CREATE2_SALT", uint256(0));

        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, salt);
        }

        if (dkim == address(0)) {
            dkim = deployUserOverrideableDKIMRegistry(
                initialOwner, dkimRegistrySigner, dkimDelay, salt
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("EmailAuth implemenation deployed at", emailAuthImpl);
        }

        EmailRecoveryUniversalFactory factory =
            new EmailRecoveryUniversalFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl);
        (address module, address commandHandler) = factory.deployUniversalEmailRecoveryModule(
            bytes32(salt),
            bytes32(salt),
            type(SafeRecoveryCommandHandler).creationCode,
            minimumDelay,
            killSwitchAuthorizer,
            address(dkim)
        );

        console.log("UniversalEmailRecoveryModule deployed at", vm.toString(module));
        console.log("SafeRecoveryCommandHandler deployed at", vm.toString(commandHandler));

        vm.stopBroadcast();
    }
}
