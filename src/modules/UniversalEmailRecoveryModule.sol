// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { SentinelListLib, SENTINEL, ZERO_ADDRESS } from "sentinellist/SentinelList.sol";
import { IUniversalEmailRecoveryModule } from "../interfaces/IUniversalEmailRecoveryModule.sol";
import { IEmailRecoveryManager } from "../interfaces/IEmailRecoveryManager.sol";
import { RecoveryModuleBase } from "./RecoveryModuleBase.sol";

/**
 * @title UniversalEmailRecoveryModule
 * @notice This contract provides a simple mechanism for recovering account validators by
 * permissioning certain functions to be called on validators. It facilitates recovery by
 * integration with a trusted email recovery manager. The module defines how a recovery request is
 * executed on a validator, while the trusted recovery manager defines what a valid
 * recovery request is
 */
contract UniversalEmailRecoveryModule is RecoveryModuleBase {
    using SentinelListLib for SentinelListLib.SentinelList;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Maximum number of validators that can be configured for recovery
     */
    uint256 public constant MAX_VALIDATORS = 32;

    /**
     * Trusted email recovery manager contract that handles recovery requests
     */
    event NewValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);
    event RemovedValidatorRecovery(address indexed validatorModule, bytes4 recoverySelector);
    event RecoveryExecuted();

    error InvalidOnInstallData();
    error MaxValidatorsReached();
    error NotTrustedRecoveryManager();

    /**
     * Account address to validator list
     */
    mapping(address account => SentinelListLib.SentinelList validatorList) internal validators;
    /**
     * Account address to validator count
     */
    mapping(address account => uint256 count) public validatorCount;

    /**
     * validator address to account address to function selector
     */
    mapping(address validatorModule => mapping(address account => bytes4 allowedSelector)) internal
        allowedSelectors;
    /**
     * function selector to account address to validator address
     */
    mapping(bytes4 selector => mapping(address account => address validator)) internal
        selectorToValidator;

    constructor(address _emailRecoveryManager) RecoveryModuleBase(_emailRecoveryManager) { }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONFIG                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Initializes the module with the threshold and guardians
     * @dev data is encoded as follows: abi.encode(validator, isInstalledContext, initialSelector,
     * guardians, weights, threshold, delay, expiry)
     *
     * @param data encoded data for recovery configuration
     */
    function onInstall(bytes calldata data) external {
        if (data.length == 0) revert InvalidOnInstallData();
        (
            address validator,
            bytes memory isInstalledContext,
            bytes4 initialSelector,
            address[] memory guardians,
            uint256[] memory weights,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(
            data, (address, bytes, bytes4, address[], uint256[], uint256, uint256, uint256)
        );

        validators[msg.sender].init();

        // Ensure the validator is installed
        // and configure valdiators for recovery
        allowValidatorRecovery(validator, isInstalledContext, initialSelector);

        _configureRecoveryManager({
            guardians: guardians,
            weights: weights,
            threshold: threshold,
            delay: delay,
            expiry: expiry
        });
    }

    /**
     * @notice Allows a validator and function selector to be used for recovery
     * @dev Ensure that the function selector does indeed correspond to the validator as
     * this cannot be checked in this function, as modules may not support ERC165
     * @param validator The validator to allow recovery for
     * @param isInstalledContext additional context data that the smart account may
     * interpret to identifiy conditions under which the module is installed.
     * @param recoverySelector The function selector to allow when executing recovery
     */
    function allowValidatorRecovery(
        address validator,
        bytes memory isInstalledContext,
        bytes4 recoverySelector
    )
        public
        withoutUnsafeSelector(recoverySelector)
    {
        _requireModuleInstalled({
            account: msg.sender,
            module: validator,
            context: isInstalledContext
        });

        if (validatorCount[msg.sender] > MAX_VALIDATORS) {
            revert MaxValidatorsReached();
        }
        validators[msg.sender].push(validator);
        validatorCount[msg.sender]++;

        allowedSelectors[validator][msg.sender] = recoverySelector;
        selectorToValidator[recoverySelector][msg.sender] = validator;

        emit NewValidatorRecovery({ validatorModule: validator, recoverySelector: recoverySelector });
    }

    /**
     * @notice Disallows a validator and function selector that has been configured for recovery
     * @param validator The validator to disallow
     * @param prevValidator The previous validator in the validators linked list
     * @param isInstalledContext additional context data that the smart account may
     * interpret to identifiy conditions under which the module is installed.
     * @param recoverySelector The function selector to disallow
     */
    function disallowValidatorRecovery(
        address validator,
        address prevValidator,
        bytes memory isInstalledContext,
        bytes4 recoverySelector
    )
        public
    {
        _requireModuleInstalled({
            account: msg.sender,
            module: validator,
            context: isInstalledContext
        });

        validators[msg.sender].pop(prevValidator, validator);
        validatorCount[msg.sender]--;

        if (allowedSelectors[validator][msg.sender] != recoverySelector) {
            revert InvalidSelector(recoverySelector);
        }

        delete allowedSelectors[validator][msg.sender];
        delete selectorToValidator[recoverySelector][msg.sender];

        emit RemovedValidatorRecovery({
            validatorModule: validator,
            recoverySelector: recoverySelector
        });
    }

    /**
     * Handles the uninstallation of the module and clears the recovery configuration
     * @dev the data parameter is not used
     */
    function onUninstall(bytes calldata /* data */ ) external {
        address[] memory allowedValidators = getAllowedValidators(msg.sender);

        for (uint256 i; i < allowedValidators.length; i++) {
            bytes4 allowedSelector = allowedSelectors[allowedValidators[i]][msg.sender];
            delete selectorToValidator[allowedSelector][msg.sender];
            delete allowedSelectors[allowedValidators[i]][msg.sender];
        }

        validators[msg.sender].popAll();
        validatorCount[msg.sender] = 0;

        EMAIL_RECOVERY_MANAGER.deInitRecoveryFromModule(msg.sender);
    }

    function isAuthorizedToRecover(address smartAccount) external view returns (bool) {
        return getAllowedValidators(smartAccount).length > 0;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODULE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Executes recovery on a validator. Must be called by the trusted recovery manager
     * @param account The account to execute recovery for
     * @param recoveryCalldata The recovery calldata that should be executed on the validator
     * being recovered
     */
    function recover(
        address account,
        bytes calldata recoveryCalldata
    )
        external
        onlyRecoveryManager
    {
        bytes4 selector = bytes4(recoveryCalldata[:4]);

        address validator = selectorToValidator[selector][account];
        bytes4 allowedSelector = allowedSelectors[validator][account];
        if (allowedSelector != selector) {
            revert InvalidSelector(selector);
        }

        _execute({ account: account, to: validator, value: 0, data: recoveryCalldata });

        emit RecoveryExecuted();
    }

    /**
     * @notice Retrieves the list of allowed validators for a given account.
     * @param account The address of the account.
     * @return address[] An array of the allowed validator addresses.
     */
    function getAllowedValidators(address account) public view returns (address[] memory) {
        (address[] memory allowedValidators,) =
            validators[account].getEntriesPaginated(SENTINEL, MAX_VALIDATORS);

        return allowedValidators;
    }

    /**
     * @notice Retrieves the list of allowed selectors for a given account.
     * @param account The address of the account.
     * @return address[] An array of allowed function selectors.
     */
    function getAllowedSelectors(address account) external view returns (bytes4[] memory) {
        address[] memory allowedValidators = getAllowedValidators(account);
        uint256 allowedValidatorsLength = allowedValidators.length;

        bytes4[] memory selectors = new bytes4[](allowedValidatorsLength);
        for (uint256 i; i < allowedValidatorsLength; i++) {
            selectors[i] = allowedSelectors[allowedValidators[i]][account];
        }

        return selectors;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         METADATA                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Returns the name of the module
     * @return name of the module
     */
    function name() external pure returns (string memory) {
        return "ZKEmail.UniversalEmailRecoveryModule";
    }

    /**
     * Returns the version of the module
     * @return version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }
}
