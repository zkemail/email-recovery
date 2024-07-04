// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { EmailRecoveryManager } from "../EmailRecoveryManager.sol";
import { EmailRecoveryModule } from "../modules/EmailRecoveryModule.sol";

/**
 * @title EmailRecoveryFactory
 * @notice This contract facilitates the deployment of email recovery modules and their associated
 * recovery managers and subject handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract EmailRecoveryFactory {
    /**
     * @notice Address of the verifier used by the recovery manager.
     */
    address public immutable verifier;

    /**
     * @notice Address of the EmailAuth.sol implementation.
     */
    address public immutable emailAuthImpl;

    event EmailRecoveryModuleDeployed(
        address emailRecoveryModule, address emailRecoveryManager, address subjectHandler
    );

    constructor(address _verifier, address _emailAuthImpl) {
        verifier = _verifier;
        emailAuthImpl = _emailAuthImpl;
    }

    /**
     * @notice Deploys an email recovery module along with its recovery manager and subject handler
     * @dev The subject handler bytecode cannot be determined ahead of time, unlike the recovery
     * manager and recovery module, which is why it is passed in directly. In practice, this means a
     * developer will write their own subject handler, and then pass the bytecode into this factory
     * function.
     *
     * This deployment function deploys an `EmailRecoveryModule`, which takes a target validator and
     * target function selector
     * @param subjectHandlerSalt Salt for the subject handler deployment
     * @param recoveryManagerSalt Salt for the recovery manager deployment
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param subjectHandlerBytecode Bytecode of the subject handler contract
     * @param dkimRegistry Address of the DKIM registry
     * @param validator Address of the validator to be recovered
     * @param functionSelector Function selector for the recovery function to be called on the
     * target validator
     * @return emailRecoveryModule The deployed email recovery module
     * @return emailRecoveryManager The deployed email recovery manager
     * @return subjectHandler The deployed subject handler
     */
    function deployEmailRecoveryModule(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryManagerSalt,
        bytes32 recoveryModuleSalt,
        bytes memory subjectHandlerBytecode,
        address dkimRegistry,
        address validator,
        bytes4 functionSelector
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
            new EmailRecoveryModule{ salt: recoveryModuleSalt }(
                emailRecoveryManager, validator, functionSelector
            )
        );

        // Initialize recovery manager with module address
        EmailRecoveryManager(emailRecoveryManager).initialize(emailRecoveryModule);
        emit EmailRecoveryModuleDeployed(emailRecoveryModule, emailRecoveryManager, subjectHandler);

        return (emailRecoveryModule, emailRecoveryManager, subjectHandler);
    }
}
