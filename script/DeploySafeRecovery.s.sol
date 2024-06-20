// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

contract DeploySafeRecoveryScript is Script {
    function run() public {
        address verifier = 0xEdC642bbaD91E21cCE6cd436Fdc6F040FD0fF998;
        address dkimRegistry = 0xC83256CCf7B94d310e49edA05077899ca036eb78;
        address emailAuthImpl = 0x1C76Aa365c17B40c7E944DcCdE4dC6e6D2A7b748;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        SafeRecoverySubjectHandler emailRecoveryHandler = new SafeRecoverySubjectHandler();

        EmailRecoveryManager emailRecoveryManager = new EmailRecoveryManager(
            verifier, dkimRegistry, emailAuthImpl, address(emailRecoveryHandler)
        );

        new EmailRecoveryModule(address(emailRecoveryManager));

        vm.stopBroadcast();
    }
}
