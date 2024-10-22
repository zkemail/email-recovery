// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import { SentinelListLib, SENTINEL } from "sentinellist/SentinelList.sol";
import { IUniversalEmailRecoveryModule } from "../interfaces/IUniversalEmailRecoveryModule.sol";
import { EmailRecoveryManager } from "../EmailRecoveryManager.sol";

/**
 * @title UniversalEmailRecoveryModule
 * @notice This contract provides a simple mechanism for recovering modular smart accounts by
 * permissioning certain functions to be called on validators. It facilitates recovery by
 * integration with the email recovery manager contract. The module defines how a recovery request
 * is executed on a validator, while the recovery manager defines what a valid recovery request is.
 *
 * This recovery module is generic and does not target a specific validator. An account may add
 * multiple validators to this recovery module, it may only recovery a single validator at a time
 */
contract UniversalEmailRecoveryModule is
    EmailRecoveryManager,
    ERC7579ExecutorBase,
    IUniversalEmailRecoveryModule
{
    using SentinelListLib for SentinelListLib.SentinelList;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Maximum number of validators that can be configured for recovery
     */
    uint256 public constant MAX_VALIDATORS = 32;

    event NewValidatorRecovery(
        address indexed account, address indexed validator, bytes4 recoverySelector
    );
    event RemovedValidatorRecovery(
        address indexed account, address indexed validator, bytes4 recoverySelector
    );
    event RecoveryExecuted(address indexed account, address indexed validator);

    error InvalidSelector(bytes4 selector);
    error RecoveryModuleNotInitialized();
    error InvalidOnInstallData();
    error InvalidValidator(address validator);
    error MaxValidatorsReached();

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
     * @notice Modifier to check whether the selector is safe
     * @dev Reverts if the selector is for "onInstall" or "onUninstall", or if the selector is not
     * on a whitelist if the validator is equal to msg.sender
     */
    modifier withoutUnsafeSelector(address validator, bytes4 selector) {
        if (validator == msg.sender) {
            if (
                selector != ISafe.addOwnerWithThreshold.selector
                    && selector != ISafe.removeOwner.selector && selector != ISafe.swapOwner.selector
                    && selector != ISafe.changeThreshold.selector
            ) {
                revert InvalidSelector(selector);
            }
        } else {
            if (
                selector == IModule.onInstall.selector || selector == IModule.onUninstall.selector
                    || selector == bytes4(0)
            ) {
                revert InvalidSelector(selector);
            }
        }
        _;
    }

    /**
     * @notice Modifier to check whether the recovery module is initialized
     */
    modifier onlyWhenInitialized() {
        if (!validators[msg.sender].alreadyInitialized()) {
            revert RecoveryModuleNotInitialized();
        }
        _;
    }

    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address commandHandler,
        uint256 minimumDelay
    )
        EmailRecoveryManager(verifier, dkimRegistry, emailAuthImpl, commandHandler, minimumDelay)
    { }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONFIG                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Initializes the module with the threshold, guardians and other configuration
     * @dev You cannot install this module during account deployment as it breaks the 4337
     * validation rules. ERC7579 does not mandate that executors abide by the validation rules
     * during account setup - if required, install this module after the account has been setup. The
     * data is encoded as follows: abi.encode(validator, isInstalledContext, initialSelector,
     * guardians, weights, threshold, delay, expiry)
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
        allowValidatorRecovery(validator, isInstalledContext, initialSelector);

        configureRecovery(guardians, weights, threshold, delay, expiry);
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
        onlyWhenInitialized
        withoutUnsafeSelector(validator, recoverySelector)
    {
        if (
            !IERC7579Account(msg.sender).isModuleInstalled(
                TYPE_VALIDATOR, validator, isInstalledContext
            )
        ) {
            revert InvalidValidator(validator);
        }

        if (validatorCount[msg.sender] >= MAX_VALIDATORS) {
            revert MaxValidatorsReached();
        }
        validators[msg.sender].push(validator);
        validatorCount[msg.sender]++;

        allowedSelectors[validator][msg.sender] = recoverySelector;
        emit NewValidatorRecovery({
            account: msg.sender,
            validator: validator,
            recoverySelector: recoverySelector
        });
    }

    /**
     * @notice Disallows a validator and function selector that has been configured for recovery
     * @param validator The validator to disallow
     * @param prevValidator The previous validator in the validators linked list
     * @param recoverySelector The function selector to disallow
     */
    function disallowValidatorRecovery(
        address validator,
        address prevValidator,
        bytes4 recoverySelector
    )
        public
        onlyWhenInitialized
    {
        validators[msg.sender].pop(prevValidator, validator);
        validatorCount[msg.sender]--;

        if (allowedSelectors[validator][msg.sender] != recoverySelector) {
            revert InvalidSelector(recoverySelector);
        }

        delete allowedSelectors[validator][msg.sender];

        emit RemovedValidatorRecovery({
            account: msg.sender,
            validator: validator,
            recoverySelector: recoverySelector
        });
    }

    /**
     * @notice Handles the uninstallation of the module and clears the recovery configuration
     * @param {data} Unused parameter.
     */
    function onUninstall(bytes calldata /* data */ ) external {
        address[] memory allowedValidators = getAllowedValidators(msg.sender);

        for (uint256 i; i < allowedValidators.length; i++) {
            delete allowedSelectors[allowedValidators[i]][msg.sender];
        }

        validators[msg.sender].popAll();
        validatorCount[msg.sender] = 0;

        deInitRecoveryModule();
    }

    /**
     * @notice Check if the module is initialized
     * @param account The smart account to check
     * @return bool True if the module is initialized, false otherwise
     */
    function isInitialized(address account) public view returns (bool) {
        return getGuardianConfig(account).threshold != 0;
    }

    /**
     * @notice Check if a recovery request can be initiated based on guardian acceptance
     * @param account The smart account to check
     * @param validator The validator to check
     * @return bool True if the recovery request can be started, false otherwise
     */
    function canStartRecoveryRequest(
        address account,
        address validator
    )
        external
        view
        returns (bool)
    {
        GuardianConfig memory guardianConfig = getGuardianConfig(account);

        return guardianConfig.threshold > 0
            && guardianConfig.acceptedWeight >= guardianConfig.threshold
            && validators[account].contains(validator);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODULE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Executes recovery on a validator. Called from the recovery manager once a recovery
     * attempt has been processed
     * @param account The account to execute recovery for
     * @param recoveryData The recovery data that should be executed on the validator being
     * recovered, along with the target validator.
     * recoveryData = abi.encode(validator, recoveryFunctionCalldata)
     */
    function recover(address account, bytes calldata recoveryData) internal override {
        (address validator, bytes memory recoveryCalldata) =
            abi.decode(recoveryData, (address, bytes));

        if (validator == address(0)) {
            revert InvalidValidator(validator);
        }

        bytes4 selector;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            selector := mload(add(recoveryCalldata, 32))
        }

        bytes4 allowedSelector = allowedSelectors[validator][account];
        if (allowedSelector != selector) {
            revert InvalidSelector(selector);
        }

        _execute({ account: account, to: validator, value: 0, data: recoveryCalldata });

        emit RecoveryExecuted(account, validator);
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
        uint256 validatorsLength = allowedValidators.length;

        bytes4[] memory selectors = new bytes4[](validatorsLength);
        for (uint256 i; i < validatorsLength; i++) {
            selectors[i] = allowedSelectors[allowedValidators[i]][account];
        }

        return selectors;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         METADATA                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the name of the module
     * @return string name of the module
     */
    function name() external pure returns (string memory) {
        return "ZKEmail.UniversalEmailRecoveryModule";
    }

    /**
     * @notice Returns the version of the module
     * @return string version of the module
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /**
     * @notice Returns the type of the module
     * @param typeID type of the module
     * @return bool true if the type is a module type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
