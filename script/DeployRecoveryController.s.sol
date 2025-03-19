// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import { console } from "forge-std/console.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { SimpleWallet } from "test/unit/helpers/SimpleWallet.sol";
import { RecoveryController } from "test/unit/helpers/RecoveryController.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { BaseDeployScript } from "./BaseDeployScript.sol";

contract Deploy is BaseDeployScript {
    using ECDSA for *;

    address dkim;
    address verifier;
    address emailAuthImpl;
    address simpleWallet;
    address recoveryController;

    function run() public override {
        super.run();
        vm.startBroadcast(deployerPrivateKey);

        // Deploy User-overrideable DKIM registry
        dkim = vm.envOr("DKIM", address(0));
        if (address(dkim) == address(0)) {
            address dkimSigner = vm.envAddress("DKIM_SIGNER");
            if (dkimSigner == address(0)) {
                console.log("DKIM_SIGNER env var not set");
                return;
            }
            uint256 timeDelay = vm.envOr("DKIM_DELAY", uint256(0));
            console.log("DKIM_DELAY: %s", timeDelay);

            dkim = deployUserOverrideableDKIMRegistry(initialOwner, dkimSigner, timeDelay);
        }

        // Deploy Verifier
        verifier = vm.envOr("VERIFIER", address(0));
        if (address(verifier) == address(0)) {
            verifier = deployVerifier(initialOwner);
        }

        // Deploy EmailAuth Implementation
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        if (emailAuthImpl == address(0)) {
            emailAuthImpl = deployEmailAuthImplementation();
        }

        // Create RecoveryController as EmailAccountRecovery implementation
        recoveryController = deployRecoveryController(
            initialOwner, address(verifier), address(dkim), address(emailAuthImpl)
        );

        // Deploy SimpleWallet Implementation
        simpleWallet = deploySimpleWallet(initialOwner, address(recoveryController));

        vm.stopBroadcast();
    }
}
