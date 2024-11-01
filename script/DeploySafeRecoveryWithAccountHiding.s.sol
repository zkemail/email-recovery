// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";

import { Safe7579 } from "safe7579/Safe7579.sol";
import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { IERC7484 } from "safe7579/interfaces/IERC7484.sol";
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
    bool enableSameTxProtection;

    address initialOwner;
    uint256 salt;

    function run() public override {
        super.run();
        address entryPoint = address(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        IERC7484 registry = IERC7484(0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        verifier = address(0);
        dkim = vm.envOr("DKIM_REGISTRY", address(0));
        dkimRegistrySigner = vm.envOr("SIGNER", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");
        enableSameTxProtection = vm.envOr("ENABLE_SAME_TX_PROTECTION", true);

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
            enableSameTxProtection,
            dkim
        );

        address safe7579 = address(new Safe7579{ salt: bytes32(uint256(0)) }());
        address safe7579Launchpad =
            address(new Safe7579Launchpad{ salt: bytes32(uint256(0)) }(entryPoint, registry));

        console.log("Deployed Email Recovery Module at  ", vm.toString(module));
        console.log("Deployed Email Recovery Handler at ", vm.toString(commandHandler));
        console.log("Deployed Safe 7579 at              ", vm.toString(safe7579));
        console.log("Deployed Safe 7579 Launchpad at    ", vm.toString(safe7579Launchpad));

        vm.stopBroadcast();
    }
}
