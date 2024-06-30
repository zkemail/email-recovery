// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { EmailRecoveryManager } from "./EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "./modules/UniversalEmailRecoveryModule.sol";
import { EmailRecoveryModule } from "./modules/EmailRecoveryModule.sol";

contract EmailRecoveryFactory {
    function deployAll(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt,
        bytes32 recoveryModuleSalt,
        bytes memory subjectHandlerBytecode,
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address validator,
        bytes4 functionSelector
    )
        external
        returns (address, address, address)
    {
        // Deploy subject handler
        address subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);

        // Deploy recovery manager
        EmailRecoveryManager emailRecoveryManager = new EmailRecoveryManager{
            salt: recoveryManagerSalt
        }(verifier, dkimRegistry, emailAuthImpl, subjectHandler);
        address emailRecoveryManagerAddress = address(emailRecoveryManager);

        // Deploy recovery module
        EmailRecoveryModule emailRecoveryModule = new EmailRecoveryModule{ salt: recoveryModuleSalt }(
            emailRecoveryManagerAddress, validator, functionSelector
        );
        address emailRecoveryModuleAddress = address(emailRecoveryModule);

        // Initialize recovery manager with module address
        emailRecoveryManager.initialize(emailRecoveryModuleAddress);

        return (emailRecoveryManagerAddress, emailRecoveryModuleAddress, subjectHandler);
    }

    function deployAllWithUniversalModule(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt,
        bytes32 recoveryModuleSalt,
        bytes memory subjectHandlerBytecode,
        address verifier,
        address dkimRegistry,
        address emailAuthImpl
    )
        external
        returns (address, address, address)
    {
        // Deploy subject handler
        address subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);

        // Deploy recovery manager
        EmailRecoveryManager emailRecoveryManager = new EmailRecoveryManager{
            salt: recoveryManagerSalt
        }(verifier, dkimRegistry, emailAuthImpl, subjectHandler);
        address emailRecoveryManagerAddress = address(emailRecoveryManager);

        // Deploy recovery module
        UniversalEmailRecoveryModule emailRecoveryModule = new UniversalEmailRecoveryModule{
            salt: recoveryModuleSalt
        }(emailRecoveryManagerAddress);
        address emailRecoveryModuleAddress = address(emailRecoveryModule);

        // Initialize recovery manager with module address
        emailRecoveryManager.initialize(emailRecoveryModuleAddress);

        return (emailRecoveryManagerAddress, emailRecoveryModuleAddress, subjectHandler);
    }
}
