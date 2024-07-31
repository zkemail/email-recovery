// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { UniversalEmailRecoveryModule } from "../modules/UniversalEmailRecoveryModule.sol";

/**
 * @title EmailRecoveryFactory
 * @notice This contract facilitates the deployment of universal email recovery modules and their
 * associated subject handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract EmailRecoveryUniversalFactory {
    address public immutable verifier;
    address public immutable emailAuthImpl;

    event UniversalEmailRecoveryModuleDeployed(address emailRecoveryModule, address subjectHandler);

    error InvalidVerifier();
    error InvalidEmailAuthImpl();

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
     * @notice Deploys a universal email recovery module along with its subject handler
     * @dev The subject handler bytecode cannot be determined ahead of time, unlike the recovery
     * module, which is why it is passed in directly. In practice, this means a
     * developer will write their own subject handler, and then pass the bytecode into this factory
     * function. The universal recovery module should have a relatively stable subject handler,
     * however, developers may want to write a generic subject handler in a slightly different way,
     * or even in a non-english lanaguage, so the bytecode is still passed in here directly.
     *
     * This deployment function deploys an `UniversalEmailRecoveryModule`, which takes the
     * target verifier, dkim registry, EmailAuth implementation and subject handler. The target
     * validator and target function selector are set when a module is installed. This is part of
     * what makes the module generic for recovering any validator
     * @param subjectHandlerSalt Salt for the subject handler deployment
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param subjectHandlerBytecode Bytecode of the subject handler contract
     * @param dkimRegistry Address of the DKIM registry.
     * @return emailRecoveryModule The deployed email recovery module
     * @return subjectHandler The deployed subject handler
     */
    function deployUniversalEmailRecoveryModule(
        bytes32 subjectHandlerSalt,
        bytes32 recoveryModuleSalt,
        bytes calldata subjectHandlerBytecode,
        address dkimRegistry
    )
        external
        returns (address, address)
    {
        // Deploy subject handler
        address subjectHandler = Create2.deploy(0, subjectHandlerSalt, subjectHandlerBytecode);

        // Deploy recovery module
        address emailRecoveryModule = address(
            new UniversalEmailRecoveryModule{ salt: recoveryModuleSalt }(
                verifier, dkimRegistry, emailAuthImpl, subjectHandler
            )
        );

        emit UniversalEmailRecoveryModuleDeployed(emailRecoveryModule, subjectHandler);

        return (emailRecoveryModule, subjectHandler);
    }
}
