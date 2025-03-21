// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {UniversalEmailRecoveryModule} from "../modules/UniversalEmailRecoveryModule.sol";

/**
 * @title EmailRecoveryUniversalFactory
 * @notice This contract facilitates the deployment of universal email recovery modules and their
 * associated command handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract EmailRecoveryUniversalFactory {
    event UniversalEmailRecoveryModuleDeployed(address emailRecoveryModule);

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
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param minimumDelay Minimum delay for recovery requests
     * @param killSwitchAuthorizer Address of the kill switch authorizer
     * @return emailRecoveryModule The deployed email recovery module
     */
    function deployUniversalEmailRecoveryModule(
        bytes32 recoveryModuleSalt,
        uint256 minimumDelay,
        address killSwitchAuthorizer
    ) external returns (address) {
        // Deploy recovery module
        address emailRecoveryModule = address(
            new UniversalEmailRecoveryModule{salt: recoveryModuleSalt}(
                minimumDelay,
                killSwitchAuthorizer
            )
        );

        emit UniversalEmailRecoveryModuleDeployed(emailRecoveryModule);

        return emailRecoveryModule;
    }
}
