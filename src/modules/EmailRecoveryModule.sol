// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe } from "../interfaces/ISafe.sol";
import { IEmailRecoveryModule } from "../interfaces/IEmailRecoveryModule.sol";
import { EmailRecoveryManager } from "../EmailRecoveryManager.sol";

/**
 * @title EmailRecoveryModule
 * @notice This contract provides a simple mechanism for recovering modular smart accounts by
 * permissioning certain functions to be called on validators. It facilitates recovery by
 * integration with the email recovery manager contract. The module defines how a recovery request
 * is executed on a validator, while the recovery manager defines what a valid recovery request is.
 *
 * This recovery module targets a specific validator, so this contract should be deployed per
 * validator
 */
contract EmailRecoveryModule is EmailRecoveryManager, ERC7579ExecutorBase, IEmailRecoveryModule {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Validator being recovered
     */
    address public immutable validator;

    /**
     * function selector that is called when recovering validator
     */
    bytes4 public immutable selector;

    /**
     * Deployment timestamp
     */
    uint256 public immutable deploymentTimestamp;

    /**
     * Account address to initiate transactions
     */
    mapping(address account => bool isInitiator) internal transactionInitiators;

    event RecoveryExecuted(address indexed account, address indexed validator);

    /**
     * @notice Modifier to check if the caller is an initiator
     */
    modifier isInitiator() {
        bool isOpenToAll = transactionInitiators[address(0)]
            || block.timestamp >= deploymentTimestamp + 6 * 30 days;

        if (!isOpenToAll) {
            require(
                transactionInitiators[msg.sender], "Only allowed accounts can call this function"
            );
        }
        _;
    }

    error InvalidSelector(bytes4 selector);
    error InvalidOnInstallData();
    error InvalidValidator(address validator);

    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address commandHandler,
        uint256 minimumDelay,
        address killSwitchAuthorizer,
        address _validator,
        bytes4 _selector
    )
        EmailRecoveryManager(
            verifier,
            dkimRegistry,
            emailAuthImpl,
            commandHandler,
            minimumDelay,
            killSwitchAuthorizer
        )
    {
        if (_validator == address(0)) {
            revert InvalidValidator(_validator);
        }
        if (_validator == msg.sender) {
            if (
                _selector != ISafe.addOwnerWithThreshold.selector
                    && _selector != ISafe.removeOwner.selector && _selector != ISafe.swapOwner.selector
                    && _selector != ISafe.changeThreshold.selector
            ) {
                revert InvalidSelector(_selector);
            }
        } else {
            if (
                _selector == IModule.onInstall.selector || _selector == IModule.onUninstall.selector
                    || _selector == bytes4(0)
            ) {
                revert InvalidSelector(_selector);
            }
        }

        validator = _validator;
        selector = _selector;
        deploymentTimestamp = block.timestamp;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONFIG                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Initializes the module with the threshold, guardians and other configuration
     * @dev You cannot install this module during account deployment as it breaks the 4337
     * validation rules. ERC7579 does not mandate that executors abide by the validation rules
     * during account setup - if required, install this module after the account has been setup. The
     * data is encoded as follows: abi.encode(isInstalledContext, guardians, weights, threshold,
     * delay, expiry)
     * @param data encoded data for recovery configuration
     */
    function onInstall(bytes calldata data) external {
        if (data.length == 0) revert InvalidOnInstallData();
        (
            bytes memory isInstalledContext,
            address[] memory guardians,
            uint256[] memory weights,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (bytes, address[], uint256[], uint256, uint256, uint256));

        if (
            !IERC7579Account(msg.sender).isModuleInstalled(
                TYPE_VALIDATOR, validator, isInstalledContext
            )
        ) {
            revert InvalidValidator(validator);
        }
        configureRecovery(guardians, weights, threshold, delay, expiry);
    }

    /**
     * @notice Handles the uninstallation of the module and clears the recovery configuration
     * @param {data} Unused parameter.
     */
    function onUninstall(bytes calldata /* data */ ) external {
        deInitRecoveryModule();
    }

    /**
     * @notice Sets the transaction initiator status for an account
     * @dev Can only be called by the kill switch authorizer
     */
    function setTransactionInitiator(address account, bool canInitiate) external onlyOwner {
        transactionInitiators[account] = canInitiate;
    }

    /**
     * @notice Check if the module is initialized
     * @param account The smart account to check
     * @return bool True if the module is initialized, false otherwise
     */
    function isInitialized(address account) external view returns (bool) {
        return getGuardianConfig(account).threshold != 0;
    }

    /**
     * @notice Check if a recovery request can be initiated based on guardian acceptance
     * @param account The smart account to check
     * @return bool True if the recovery request can be started, false otherwise
     */
    function canStartRecoveryRequest(address account) external view returns (bool) {
        GuardianConfig memory guardianConfig = getGuardianConfig(account);

        return guardianConfig.threshold > 0
            && guardianConfig.acceptedWeight >= guardianConfig.threshold;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODULE LOGIC                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Executes recovery on a validator. Called from the recovery manager once a recovery
     * attempt has been processed
     * @param account The account to execute recovery for
     * @param recoveryData The recovery data that should be executed on the validator
     * being recovered. recoveryData = abi.encode(validator, recoveryFunctionCalldata)
     */
    function recover(address account, bytes calldata recoveryData) internal override {
        (, bytes memory recoveryCalldata) = abi.decode(recoveryData, (address, bytes));

        bytes4 calldataSelector;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            calldataSelector := mload(add(recoveryCalldata, 32))
        }
        if (calldataSelector != selector) {
            revert InvalidSelector(calldataSelector);
        }

        _execute({ account: account, to: validator, value: 0, data: recoveryCalldata });

        emit RecoveryExecuted(account, validator);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         METADATA                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the name of the module
     * @return string name of the module
     */
    function name() external pure returns (string memory) {
        return "ZKEmail.EmailRecoveryModule";
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

    /**
     * @notice Accepts a guardian for the specified account. This is the second core function
     * that must be called during the end-to-end recovery flow
     * @dev Called once per guardian added. Although this adds an extra step to recovery, this
     * acceptance flow is an important security feature to ensure that no typos are made when adding
     * a guardian, and that the guardian is in control of the specified email address. Called as
     * part of handleAcceptance in EmailAccountRecovery
     * @param guardian The address of the guardian to be accepted
     * @param templateIdx The index of the template used for acceptance
     * @param commandParams An array of bytes containing the command parameters
     * @param nullifier The unique identifier for an email (unused in this implementation)
     */
    function acceptGuardian(
        address guardian,
        uint256 templateIdx,
        bytes[] memory commandParams,
        bytes32 nullifier
    )
        internal
        override(EmailRecoveryManager)
        isInitiator
    {
        super.acceptGuardian(guardian, templateIdx, commandParams, nullifier);
    }

    /**
     * @notice Processes a recovery request for a given account. This is the third core function
     * that must be called during the end-to-end recovery flow
     * @dev Called once per guardian until the threshold is reached
     * @param guardian The address of the guardian initiating/voting on the recovery request
     * @param templateIdx The index of the template used for the recovery request
     * @param commandParams An array of bytes containing the command parameters
     * @param nullifier The unique identifier for an email (unused in this implementation)
     */
    function processRecovery(
        address guardian,
        uint256 templateIdx,
        bytes[] memory commandParams,
        bytes32 nullifier
    )
        internal
        override(EmailRecoveryManager)
        isInitiator
    {
        super.processRecovery(guardian, templateIdx, commandParams, nullifier);
    }
}
