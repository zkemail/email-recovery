// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { EmailRecoveryManager } from "../EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "../modules/UniversalEmailRecoveryModule.sol";

/**
 * @title EmailRecoveryFactory
 * @notice This contract facilitates the deployment of universal email recovery modules and their
 * associated recovery managers and subject handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract EmailRecoveryUniversalFactory {
    address public immutable verifier;
    address public immutable emailAuthImpl;

    event UniversalEmailRecoveryModuleDeployed(
        address emailRecoveryModule, address emailRecoveryManager, address subjectHandler
    );

    constructor(address _verifier, address _emailAuthImpl) {
        verifier = _verifier;
        emailAuthImpl = _emailAuthImpl;
    }

    /**
     * @notice Deploys a universal email recovery module along with its recovery manager and subject
     * handler
     * @dev The subject handler bytecode cannot be determined ahead of time, unlike the recovery
     * manager and recovery module, which is why it is passed in directly. In practice, this means a
     * developer will write their own subject handler, and then pass the bytecode into this factory
     * function. The universal recovery module should have a relatively stable subject handler,
     * however, developers may want to write a generic subject handler in a slightly different way,
     * or even in a non-english lanaguage, so the bytecode is still passed in here directly.
     *
     * This deployment function deploys an `UniversalEmailRecoveryModule`, which only takes the
     * target emailRecoveryManager. The target validator and target function selector are set when a
     * module is installed. This is part of what makes the module generic for recovering any
     * validator
     * @param subjectHandlerSalt Salt for the subject handler deployment
     * @param recoveryManagerSalt Salt for the recovery manager deployment
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param subjectHandlerBytecode Bytecode of the subject handler contract
     * @param dkimRegistry Address of the DKIM registry.
     * @return emailRecoveryModule The deployed email recovery module
     * @return emailRecoveryManager The deployed email recovery manager
     * @return subjectHandler The deployed subject handler
     */
    function deployUniversalEmailRecoveryModule(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt,
        bytes32 recoveryModuleSalt,
        bytes calldata subjectHandlerBytecode,
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
        emit UniversalEmailRecoveryModuleDeployed(
            emailRecoveryModule, emailRecoveryManager, subjectHandler
        );

        return (emailRecoveryModule, emailRecoveryManager, subjectHandler);
    }
}
