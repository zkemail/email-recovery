// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { BaseDeployScript } from "../BaseDeployScript.s.sol";

// 1. `source .env`
// 2. `forge script --chain sepolia script/DeploySafeRecovery.s.sol:DeploySafeRecovery_Script
// --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv`
contract DeploySafeRecovery_Script is BaseDeployScript {
    address public verifier;
    address public dkim;
    address public emailAuthImpl;
    uint256 public minimumDelay;
    address public killSwitchAuthorizer;
    address public factory;

    address public initialOwner;
    address public dkimRegistrySigner;
    uint256 public dkimDelay;
    uint256 public salt;

    function run() public override {
        super.run();

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        verifier = vm.envOr("VERIFIER", address(0));
        dkim = vm.envOr("DKIM_REGISTRY", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");
        factory = vm.envOr("RECOVERY_FACTORY", address(0));

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

        if (factory == address(0)) {
            factory = address(
                new EmailRecoveryUniversalFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl)
            );
            console.log("EmailRecoveryUniversalFactory deployed at", factory);
        }

        EmailRecoveryUniversalFactory emailRecoveryUniversalFactory =
            EmailRecoveryUniversalFactory(factory);
        (address module, address commandHandler) = emailRecoveryUniversalFactory
            .deployUniversalEmailRecoveryModule(
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
