// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { EmailRecoveryModule } from "../modules/EmailRecoveryModule.sol";

/**
 * @title EmailRecoveryFactory
 * @notice This contract facilitates the deployment of email recovery modules and their associated
 * subject handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract EmailRecoveryFactory {
    /**
     * @notice Address of the verifier used by the recovery module.
     */
    address public immutable verifier;

    /**
     * @notice Address of the EmailAuth.sol implementation.
     */
    address public immutable emailAuthImpl;

    error InvalidVerifier();
    error InvalidEmailAuthImpl();

    event EmailRecoveryModuleDeployed(
        address emailRecoveryModule,
        address subjectHandler,
        address validator,
        bytes4 functionSelector
    );

    constructor(address _verifier, address _emailAuthImpl) {
        if (_verifier == address(0)) {
            revert InvalidVerifier();
        }
        if (_emailAuthImpl == address(0)) {
            revert InvalidEmailAuthImpl();
        }
        verifier = _verifier;
        emailAuthImpl = _emailAuthImpl;
    }

    /**
     * @notice Deploys an email recovery module along with its subject handler
     * @dev The subject handler bytecode cannot be determined ahead of time, unlike the recovery
     * module, which is why it is passed in directly. In practice, this means a
     * developer will write their own subject handler, and then pass the bytecode into this factory
     * function.
     *
     * This deployment function deploys an `EmailRecoveryModule`, which takes a target validator and
     * target function selector
     * @param subjectHandlerSalt Salt for the subject handler deployment
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param subjectHandlerBytecode Bytecode of the subject handler contract
     * @param dkimRegistry Address of the DKIM registry
     * @param validator Address of the validator to be recovered
     * @param functionSelector Function selector for the recovery function to be called on the
     * target validator
     * @return emailRecoveryModule The deployed email recovery module
     * @return subjectHandler The deployed subject handler
     */
    function deployEmailRecoveryModule(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryModuleSalt,
        bytes calldata subjectHandlerBytecode,
        address dkimRegistry,
        address validator,
        bytes4 functionSelector
    )
        external
        returns (address, address)
    {
        // Deploy subject handler
        address subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);

        // Deploy recovery module
        address emailRecoveryModule = address(
            new EmailRecoveryModule{ salt: recoveryModuleSalt }(
                verifier, dkimRegistry, emailAuthImpl, subjectHandler, validator, functionSelector
            )
        );

        emit EmailRecoveryModuleDeployed(
            emailRecoveryModule, subjectHandler, validator, functionSelector
        );

        return (emailRecoveryModule, subjectHandler);
    }
}
