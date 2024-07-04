// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { Verifier } from "ether-email-auth/packages/contracts/src/utils/Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

contract DeployUniversalEmailRecoveryModuleScript is Script {
    function run() public {
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

        EmailRecoverySubjectHandler emailRecoveryHandler = new EmailRecoverySubjectHandler();

        address _factory = vm.envOr("RECOVERY_FACTORY", address(0));
        if (_factory == address(0)) {
            _factory = address(new EmailRecoveryUniversalFactory(verifier, emailAuthImpl));
            console.log("Deployed Email Recovery Factory at", _factory);
        }
        {
            EmailRecoveryUniversalFactory factory = EmailRecoveryUniversalFactory(_factory);
            (address module, address manager, address subjectHandler) = factory
                .deployUniversalEmailRecoveryModule(
                bytes32(uint256(0)),
                bytes32(uint256(0)),
                bytes32(uint256(0)),
                type(EmailRecoverySubjectHandler).creationCode,
                dkimRegistry
            );

            console.log("Deployed Email Recovery Module at", vm.toString(module));
            console.log("Deployed Email Recovery Manager at", vm.toString(manager));
            console.log("Deployed Email Recovery Handler at", vm.toString(subjectHandler));
            vm.stopBroadcast();
        }
    }
}
