// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";

contract DeploySafeNativeRecovery_Script is BaseDeployScript {
    function run() public override {
        super.run();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address verifier = vm.envOr("VERIFIER", address(0));
        address eoaVerifier; /// [TODO]: Store value here later.
        address dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        address eoaAuthImpl; /// [TODO]: Store value here later.
        address commandHandler = vm.envOr("COMMAND_HANDLER", address(0));
        uint256 minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        address killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        uint256 salt = vm.envOr("CREATE2_SALT", uint256(0));

        console.log("verifier %s", verifier);

        UserOverrideableDKIMRegistry dkim;

        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, salt);
        }

        // Deploy Useroverridable DKIM registry
        dkim = UserOverrideableDKIMRegistry(vm.envOr("DKIM_REGISTRY", address(0)));
        uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
        if (address(dkim) == address(0)) {
            dkim = UserOverrideableDKIMRegistry(
                deployUserOverrideableDKIMRegistry(
                    initialOwner, dkimRegistrySigner, setTimeDelay, salt
                )
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        if (commandHandler == address(0)) {
            commandHandler =
                address(new AccountHidingRecoveryCommandHandler{ salt: bytes32(salt) }());
            console.log("Deployed Command Handler at", commandHandler);
        }

        address module = address(
            new SafeEmailRecoveryModule{ salt: bytes32(salt) }(
                verifier,
                eoaVerifier, /// @dev - This interface is originally implemented in the EOA-TX-builder module.
                address(dkim),
                emailAuthImpl,
                eoaAuthImpl, /// @dev - This interface is originally implemented in the EOA-TX-builder module.
                commandHandler,
                minimumDelay,
                killSwitchAuthorizer
            )
        );

        console.log("Deployed Email Recovery Module at  ", vm.toString(module));

        vm.stopBroadcast();
    }
}
