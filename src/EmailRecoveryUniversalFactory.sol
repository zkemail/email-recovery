// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { EmailRecoveryManager } from "./EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "./modules/UniversalEmailRecoveryModule.sol";

contract EmailRecoveryUniversalFactory {
    address public immutable verifier;
    address public immutable emailAuthImpl;

    event EmailRecoveryModuleDeployed(
        address emailRecoveryModule, address emailRecoveryManager, address subjectHandler
    );

    constructor(address _verifier, address _emailAuthImpl) {
        verifier = _verifier;
        emailAuthImpl = _emailAuthImpl;
    }

    function deployUniversalEmailRecoveryModule(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt,
        bytes32 recoveryModuleSalt,
        bytes memory subjectHandlerBytecode,
        address dkimRegistry
    )
        external
        returns (address, address, address)
    {
        // Deploy subject handler
        address subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);

        // Deploy recovery manager
        address emailRecoveryManager = address(
            new EmailRecoveryManager{ salt: recoveryManagerSalt }(
                verifier, dkimRegistry, emailAuthImpl, subjectHandler
            )
        );

        // Deploy recovery module
        address emailRecoveryModule = address(
            new UniversalEmailRecoveryModule{ salt: recoveryModuleSalt }(emailRecoveryManager)
        );

        // Initialize recovery manager with module address
        EmailRecoveryManager(emailRecoveryManager).initialize(emailRecoveryModule);
        emit EmailRecoveryModuleDeployed(emailRecoveryModule, emailRecoveryManager, subjectHandler);

        return (emailRecoveryModule, emailRecoveryManager, subjectHandler);
    }
}
