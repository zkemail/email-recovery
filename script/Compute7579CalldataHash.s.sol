// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { Verifier } from "ether-email-auth/packages/contracts/src/utils/Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { EmailRecoveryFactory } from "src/EmailRecoveryFactory.sol";

contract Compute7579CalldataHash is Script {
    bytes4 functionSelector = bytes4(keccak256(bytes("changeOwner(address,address,address)")));

    function run() public {
        address accountAddr = vm.envAddress("ACCOUNT");
        address recoveryModuleAddr = vm.envAddress("RECOVERY_MODULE");
        address newOwner = vm.envAddress("NEW_OWNER");
        bytes memory recoveryCalldata =
            abi.encodeWithSelector(functionSelector, accountAddr, newOwner, recoveryModuleAddr);
        console.log("recoveryCalldata", vm.toString(recoveryCalldata));
        bytes32 calldataHash = keccak256(recoveryCalldata);
        console.log("calldataHash", vm.toString(calldataHash));
        // vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        // address verifier = vm.envOr("VERIFIER", address(0));
        // address dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        // address dkimRegistrySigner = vm.envOr("SIGNER", address(0));
        // address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));

        // if (verifier == address(0)) {
        //     verifier = address(new Verifier());
        //     // vm.setEnv("VERIFIER", vm.toString(verifier));
        //     console.log("Deployed Verifier at", verifier);
        // }

        // if (dkimRegistry == address(0)) {
        //     require(
        //         dkimRegistrySigner != address(0),
        //         "DKIM_REGISTRY_SIGNER is required"
        //     );
        //     dkimRegistry = address(
        //         new ECDSAOwnedDKIMRegistry(dkimRegistrySigner)
        //     );
        //     // vm.setEnv("DKIM_REGISTRY", vm.toString(dkimRegistry));
        //     console.log("Deployed DKIM Registry at", dkimRegistry);
        // }

        // if (emailAuthImpl == address(0)) {
        //     emailAuthImpl = address(new EmailAuth());
        //     // vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(emailAuthImpl));
        //     console.log("Deployed Email Auth at", emailAuthImpl);
        // }

        // EmailRecoverySubjectHandler emailRecoveryHandler = new EmailRecoverySubjectHandler();
        // // vm.setEnv(
        // //     "RECOVERY_HANDLER",
        // //     vm.toString(address(emailRecoveryHandler))
        // // );
        // address _factory = vm.envOr("RECOVERY_FACTORY", address(0));
        // if (_factory == address(0)) {
        //     _factory = address(new EmailRecoveryFactory());
        //     // vm.setEnv("RECOVERY_FACTORY", vm.toString(_factory));
        //     console.log("Deployed Email Recovery Factory at", _factory);
        // }
        // EmailRecoveryFactory factory = EmailRecoveryFactory(_factory);
        // (address manager, address module) = factory.deployAllWithUniversalModule(
        //     verifier,
        //     dkimRegistry,
        //     emailAuthImpl,
        //     address(emailRecoveryHandler)
        // );
        // // vm.setEnv("RECOVERY_MANAGER", vm.toString(manager));
        // // vm.setEnv("RECOVERY_MODULE", vm.toString(module));

        // console.log(
        //     "Deployed Email Recovery Handler at",
        //     address(emailRecoveryHandler)
        // );
        // console.log("Deployed Email Recovery Manager at", vm.toString(manager));
        // console.log("Deployed Email Recovery Module at", vm.toString(module));
        // vm.stopBroadcast();
    }
}
