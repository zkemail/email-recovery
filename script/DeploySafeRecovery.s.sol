// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { Verifier } from "ether-email-auth/packages/contracts/src/utils/Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { Safe7579 } from "safe7579/Safe7579.sol";
import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { IERC7484 } from "safe7579/interfaces/IERC7484.sol";

// 1. `source .env`
// 2. `forge script --chain sepolia script/DeploySafeRecovery.s.sol:DeploySafeRecovery_Script
// --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv`
contract DeploySafeRecovery_Script is Script {
    function run() public {
        bytes32 salt = bytes32(uint256(0));
        address entryPoint = address(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        IERC7484 registry = IERC7484(0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address verifier = vm.envOr("VERIFIER", address(0));
        address dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        address dkimRegistrySigner = vm.envOr("SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));

        if (verifier == address(0)) {
            verifier = address(new Verifier());
            console.log("Deployed Verifier at", verifier);
        }

        if (dkimRegistry == address(0)) {
            require(dkimRegistrySigner != address(0), "DKIM_REGISTRY_SIGNER is required");
            dkimRegistry = address(new ECDSAOwnedDKIMRegistry(dkimRegistrySigner));
            console.log("Deployed DKIM Registry at", dkimRegistry);
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        address emailRecoveryHandler = address(new SafeRecoverySubjectHandler());
        address emailRecoveryManager = address(
            new EmailRecoveryManager(verifier, dkimRegistry, emailAuthImpl, emailRecoveryHandler)
        );
        address emailRecoveryModule =
            address(new UniversalEmailRecoveryModule(emailRecoveryManager));

        EmailRecoveryManager(emailRecoveryManager).initialize(emailRecoveryModule);

        address safe7579 = address(new Safe7579{ salt: salt }());
        address safe7579Launchpad =
            address(new Safe7579Launchpad{ salt: salt }(entryPoint, registry));

        console.log("Deployed Email Recovery Module at  ", vm.toString(emailRecoveryModule));
        console.log("Deployed Email Recovery Manager at ", vm.toString(emailRecoveryManager));
        console.log("Deployed Email Recovery Handler at ", vm.toString(emailRecoveryHandler));
        console.log("Deployed Safe 7579 at              ", vm.toString(safe7579));
        console.log("Deployed Safe 7579 Launchpad at    ", vm.toString(safe7579Launchpad));

        vm.stopBroadcast();
    }
}
