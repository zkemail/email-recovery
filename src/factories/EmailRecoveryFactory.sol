// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {EmailRecoveryModule} from "../modules/EmailRecoveryModule.sol";

/**
 * @title EmailRecoveryFactory
 * @notice This contract facilitates the deployment of email recovery modules and their associated
 * command handlers.
 * Create2 is leveraged to ensure deterministic addresses, which assists with module
 * attestations
 */
contract EmailRecoveryFactory {
    event EmailRecoveryModuleDeployed(
        address emailRecoveryModule,
        address commandHandler,
        address validator,
        bytes4 functionSelector
    );

    /**
     * @notice Deploys an email recovery module along with its command handler
     * @dev The command handler bytecode cannot be determined ahead of time, unlike the recovery
     * module, which is why it is passed in directly. In practice, this means a
     * developer will write their own command handler, and then pass the bytecode into this factory
     * function.
     *
     * This deployment function deploys an `EmailRecoveryModule`, which takes a target validator and
     * target function selector
     * @param commandHandlerSalt Salt for the command handler deployment
     * @param recoveryModuleSalt Salt for the recovery module deployment
     * @param commandHandlerBytecode Bytecode of the command handler contract
     * @param minimumDelay Minimum delay for recovery requests
     * @param killSwitchAuthorizer Address of the kill switch authorizer
     * @param validator Address of the validator to be recovered
     * @param functionSelector Function selector for the recovery function to be called on the
     * target validator
     * @return emailRecoveryModule The deployed email recovery module
     * @return commandHandler The deployed command handler
     */
    function deployEmailRecoveryModule(
        bytes32 commandHandlerSalt,
        bytes32 recoveryModuleSalt,
        bytes calldata commandHandlerBytecode,
        uint256 minimumDelay,
        address killSwitchAuthorizer,
        address validator,
        bytes4 functionSelector
    ) external returns (address, address) {
        // Deploy command handler
        address commandHandler = Create2.deploy(
            0,
            commandHandlerSalt,
            commandHandlerBytecode
        );

        // Deploy recovery module
        address emailRecoveryModule = address(
            new EmailRecoveryModule{salt: recoveryModuleSalt}(
                minimumDelay,
                killSwitchAuthorizer,
                validator,
                functionSelector
            )
        );

        emit EmailRecoveryModuleDeployed(
            emailRecoveryModule,
            commandHandler,
            validator,
            functionSelector
        );

        return (emailRecoveryModule, commandHandler);
    }
}
