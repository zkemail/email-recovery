// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { UniversalEmailRecoveryModule } from "../modules/UniversalEmailRecoveryModule.sol";

/**
 * @title EmailRecoveryUniversalFactory
 * @notice This contract facilitates the deployment of universal email recovery modules and their
 * associated command handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract EmailRecoveryUniversalFactory {
    /**
     * @notice Address of the verifier used by the recovery module.
     */
    address public immutable verifier;

    /**
     * @notice Address of the EOA verifier used by the recovery module.
     */
    address public immutable eoaVerifier; /// @dev - This is originally come from the EOA-TX-builder module.

    /**
     * @notice Address of the EmailAuth.sol implementation.
     */
    address public immutable emailAuthImpl;

    /**
     * @notice Address of the EoaAuth.sol implementation.
     */
    address public immutable eoaAuthImpl; /// @dev - This is originally come from the EOA-TX-builder module.


    event UniversalEmailRecoveryModuleDeployed(address emailRecoveryModule, address commandHandler);

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
        eoaVerifier = _eoaVerifier;     /// @dev - This is originally come from the EOA-TX-builder module.
        emailAuthImpl = _emailAuthImpl;
        eoaAuthImpl = _eoaAuthImpl;     /// @dev - This is originally come from the EOA-TX-builder module.
    }

    /**
     * @notice Deploys a universal email recovery module along with its command handler
     * @dev The command handler bytecode cannot be determined ahead of time, unlike the recovery
     * module, which is why it is passed in directly. In practice, this means a
     * developer will write their own command handler, and then pass the bytecode into this factory
     * function. The universal recovery module should have a relatively stable command handler,
     * however, developers may want to write a generic command handler in a slightly different way,
     * or even in a non-english lanaguage, so the bytecode is still passed in here directly.
     *
     * This deployment function deploys an `UniversalEmailRecoveryModule`, which takes the
     * target verifier, dkim registry, EmailAuth implementation and command handler. The target
     * validator and target function selector are set when a module is installed. This is part of
     * what makes the module generic for recovering any validator
     * @param commandHandlerSalt Salt for the command handler deployment
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param commandHandlerBytecode Bytecode of the command handler contract
     * @param minimumDelay Minimum delay for recovery requests
     * @param killSwitchAuthorizer Address of the kill switch authorizer
     * @param dkimRegistry Address of the DKIM registry.
     * @return emailRecoveryModule The deployed email recovery module
     * @return commandHandler The deployed command handler
     */
    function deployUniversalEmailRecoveryModule(
        bytes32 commandHandlerSalt,
        bytes32 recoveryModuleSalt,
        bytes calldata commandHandlerBytecode,
        uint256 minimumDelay,
        address killSwitchAuthorizer,
        address dkimRegistry
    )
        external
        returns (address, address)
    {
        // Deploy command handler
        address commandHandler = Create2.deploy(0, commandHandlerSalt, commandHandlerBytecode);

        // Deploy recovery module
        address emailRecoveryModule = address(
            new UniversalEmailRecoveryModule{ salt: recoveryModuleSalt }(
                verifier,
                eoaVerifier, /// @dev - EOA Verifier, which is originally come from the EOA-TX-builder module.
                dkimRegistry,
                emailAuthImpl,
                eoaAuthImpl, /// @dev - EOA Verifier, which is originally come from the EOA-TX-builder module.
                commandHandler,
                minimumDelay,
                killSwitchAuthorizer
            )
        );

        emit UniversalEmailRecoveryModuleDeployed(emailRecoveryModule, commandHandler);

        return (emailRecoveryModule, commandHandler);
    }
}
