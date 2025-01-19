// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ERC7579ExecutorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { ISimpleRecoveryModuleManager } from "../interfaces/ISimpleRecoveryModuleManager.sol";
import { SimpleRecoveryModuleManager } from "../SimpleRecoveryManager.sol";
import { ISimpleGuardianManager } from "../interfaces/ISimpleGuardianManager.sol";

contract SimpleRecoveryModule is SimpleRecoveryModuleManager, ERC7579ExecutorBase {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Validator address for executing recovery requests
    address public immutable validator;

    // Function selector that should match the recovery function call
    bytes4 public immutable selector;

    // Errors
    error InvalidOnInstallData();
    error InvalidValidator(address validator);

    /**
     * @notice Constructor to initialize the recovery module with required parameters
     * @param verifier Address responsible for verification
     * @param dkimRegistry Address of the DKIM registry
     * @param emailAuthImpl Implementation of email-based authentication
     * @param commandHandler Address responsible for handling commands
     * @param minimumDelay Minimum delay before executing recovery
     * @param killSwitchAuthorizer Address that can trigger the kill switch
     * @param _validator Address to which recovery transactions are executed
     * @param _selector Function selector for validation
     */
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
        SimpleRecoveryModuleManager(
            verifier,
            dkimRegistry,
            emailAuthImpl,
            commandHandler,
            minimumDelay,
            killSwitchAuthorizer
        )
    {
        validator = _validator;
        selector = _selector;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          CONFIG                             */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Initializes the module with the threshold, guardians, and other configuration
     * @dev Cannot be installed during account deployment due to validation rules. Install after setup.
     * @param data Encoded data for recovery configuration
     */
    function onInstall(bytes calldata data) external {
        if (data.length == 0) revert InvalidOnInstallData();

        (
            bytes memory isInstalledContext,
            address[] memory guardians,
            uint256[] memory weights,
            ISimpleGuardianManager.GuardianType[] memory guardianTypes,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (bytes, address[], uint256[], ISimpleGuardianManager.GuardianType[], uint256, uint256, uint256));

        configureRecovery(guardians, weights, guardianTypes, threshold, delay, expiry);
    }

    /**
     * @notice De-initializes the recovery module and clears stored configuration
     */
    function onUninstall(bytes calldata /* data */) external {
        deInitRecoveryModule();
    }

    /**
     * @notice Checks if the recovery module is initialized for a specific account
     * @param account The account address to check
     * @return bool True if the module is initialized, false otherwise
     */
    function isInitialized(address account) external view returns (bool) {
        return getGuardianConfig(account).threshold != 0;
    }

    /**
     * @notice Returns the type of the module
     * @param typeID Type ID of the module
     * @return bool True if the type is an executor module, false otherwise
     */
    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }

    /**
     * @notice Checks if a recovery request can be started based on guardian acceptance
     * @param account The account to check
     * @return bool True if the recovery request can be started, false otherwise
     */
    function canStartRecoveryRequest(address account) external view returns (bool) {
        GuardianConfig memory guardianConfig = getGuardianConfig(account);
        return guardianConfig.threshold > 0 && guardianConfig.acceptedWeight >= guardianConfig.threshold;
    }

    /**
     * @notice Processes the recovery request
     * @param account The account to recover
     * @param recoveryData Encoded recovery data
     */
    function recover(address account, bytes calldata recoveryData) internal virtual override {
        (, bytes memory recoveryCalldata) = abi.decode(recoveryData, (address, bytes));

        // Extract function selector from the calldata
        bytes4 calldataSelector;
        assembly {
            calldataSelector := mload(add(recoveryCalldata, 32))
        }

        // Validate that the selector matches the expected recovery selector
        if (calldataSelector != selector) {
            revert InvalidSelector();
        }

        // Execute the recovery transaction
        _execute({
            account: account,
            to: validator,
            value: 0,
            data: recoveryCalldata
        });

        emit RecoveryExecuted(account, account);
    }

    /**
     * @notice Helper function for testing recovery processing
     * @param guardian Address of the guardian initiating the request
     * @param templateIdx Index of the recovery template
     * @param commandParams Parameters passed to the recovery command
     */
    function testProcessRecovery(
        address guardian,
        uint256 templateIdx,
        bytes[] memory commandParams
    ) external {
        processRecovery(guardian, templateIdx, commandParams, "");
    }
}
