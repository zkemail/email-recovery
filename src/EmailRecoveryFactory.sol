// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailRecoveryManager } from "./EmailRecoveryManager.sol";
import { EmailRecoveryModule } from "./modules/EmailRecoveryModule.sol";
import { EmailRecoverySubjectHandler } from "./handlers/EmailRecoverySubjectHandler.sol";

contract EmailRecoveryFactory {
    function deployModuleAndManager(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address emailRecoveryHandler
    )
        external
        returns (address, address)
    {
        EmailRecoveryManager emailRecoveryManager =
            new EmailRecoveryManager(verifier, dkimRegistry, emailAuthImpl, emailRecoveryHandler);
        EmailRecoveryModule emailRecoveryModule =
            new EmailRecoveryModule(address(emailRecoveryManager));

        return (address(emailRecoveryManager), address(emailRecoveryModule));
    }
}
