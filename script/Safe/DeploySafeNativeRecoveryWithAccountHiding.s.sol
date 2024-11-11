// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { BaseDeployScript } from "../BaseDeployScript.s.sol";

contract DeploySafeNativeRecovery_Script is BaseDeployScript {
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

        // Deploy Useroverridable DKIM registry
        if (address(dkim) == address(0)) {
            dkim = deployUserOverrideableDKIMRegistry(
                initialOwner, dkimRegistrySigner, dkimDelay, salt
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("EmailAuth implemenation deployed at", emailAuthImpl);
        }

        if (commandHandler == address(0)) {
            commandHandler =
                address(new AccountHidingRecoveryCommandHandler{ salt: bytes32(salt) }());
            console.log("Deployed Command Handler at", commandHandler);
        }

        address module = address(
            new SafeEmailRecoveryModule{ salt: bytes32(salt) }(
                verifier,
                address(dkim),
                emailAuthImpl,
                commandHandler,
                minimumDelay,
                killSwitchAuthorizer
            )
        );

        console.log("SafeEmailRecoveryModule deployed at  ", vm.toString(module));

        vm.stopBroadcast();
    }
}
