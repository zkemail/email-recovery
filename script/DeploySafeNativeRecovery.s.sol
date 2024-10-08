// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Verifier } from "ether-email-auth/packages/contracts/src/utils/Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySafeNativeRecovery_Script is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address verifier = vm.envOr("VERIFIER", address(0));
        address dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        address dkimRegistrySigner = vm.envOr("SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        address subjectHandler = vm.envOr("SUBJECT_HANDLER", address(0));

        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        if (verifier == address(0)) {
            Verifier verifierImpl = new Verifier();
            console.log("Verifier implementation deployed at: %s", address(verifierImpl));
            ERC1967Proxy verifierProxy = new ERC1967Proxy(
                address(verifierImpl), abi.encodeCall(verifierImpl.initialize, (initialOwner))
            );
            verifier = address(Verifier(address(verifierProxy)));
            vm.setEnv("VERIFIER", vm.toString(address(verifier)));
            console.log("Deployed Verifier at", verifier);
        }

        if (dkimRegistry == address(0)) {
            require(dkimRegistrySigner != address(0), "DKIM_REGISTRY_SIGNER is required");

            ECDSAOwnedDKIMRegistry dkimImpl = new ECDSAOwnedDKIMRegistry();
            console.log("ECDSAOwnedDKIMRegistry implementation deployed at: %s", address(dkimImpl));
            ERC1967Proxy dkimProxy = new ERC1967Proxy(
                address(dkimImpl),
                abi.encodeCall(dkimImpl.initialize, (initialOwner, dkimRegistrySigner))
            );
            dkimRegistry = address(ECDSAOwnedDKIMRegistry(address(dkimProxy)));
            vm.setEnv("ECDSA_DKIM", vm.toString(address(dkimRegistry)));
            console.log("Deployed DKIM Registry at", dkimRegistry);
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        if (subjectHandler == address(0)) {
            subjectHandler = address(new SafeRecoverySubjectHandler());
            console.log("Deployed Subject Handler at", subjectHandler);
        }

        address module = address(
            new SafeEmailRecoveryModule(verifier, dkimRegistry, emailAuthImpl, subjectHandler)
        );

        console.log("Deployed Email Recovery Module at  ", vm.toString(module));

        vm.stopBroadcast();
    }
}
