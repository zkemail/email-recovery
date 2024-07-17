// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EnumerableGuardianMap, GuardianStorage, GuardianStatus } from "./EnumerableGuardianMap.sol";
import { IEmailRecoveryManager } from "../interfaces/IEmailRecoveryManager.sol";

/**
 * A helper library to manage guardians
 */
library GuardianUtils {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    event AddedGuardian(address indexed account, address indexed guardian);
    event RemovedGuardian(address indexed account, address indexed guardian);
    event ChangedThreshold(address indexed account, uint256 threshold);

    error IncorrectNumberOfWeights();
    error ThresholdCannotBeZero();
    error InvalidGuardianAddress();
    error InvalidGuardianWeight();
    error AddressAlreadyGuardian();
    error ThresholdExceedsTotalWeight();
    error StatusCannotBeTheSame();
    error SetupNotCalled();
    error UnauthorizedAccountForGuardian();

    /**
     * @notice Retrieves the guardian storage details for a given guardian and account
     * @param account The address of the account associated with the guardian
     * @param guardian The address of the guardian
     * @return GuardianStorage The guardian storage details for the specified guardian and account
     */
    function getGuardianStorage(
        mapping(address => EnumerableGuardianMap.AddressToGuardianMap) storage guardiansStorage,
        address account,
        address guardian
    )
        internal
        view
        returns (GuardianStorage memory)
    {
        return guardiansStorage[account].get(guardian);
    }

    /**
     * @notice Sets up guardians for a given account with specified weights and threshold
     * @dev This function can only be called once and ensures the guardians, weights, and threshold
     * are correctly configured
     * @param guardiansStorage The guardian storage associated with an account
     * @param account The address of the account for which guardians are being set up
     * @param guardians An array of guardian addresses
     * @param weights An array of weights corresponding to each guardian
     * @param threshold The threshold weight required for guardians to approve recovery attempts
     */
    function setupGuardians(
        mapping(address => IEmailRecoveryManager.GuardianConfig) storage guardianConfigs,
        mapping(address => EnumerableGuardianMap.AddressToGuardianMap) storage guardiansStorage,
        address account,
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold
    )
        internal
    {
        uint256 guardianCount = guardians.length;

        if (guardianCount != weights.length) {
            revert IncorrectNumberOfWeights();
        }

        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < guardianCount; i++) {
            address guardian = guardians[i];
            uint256 weight = weights[i];

            if (guardian == address(0) || guardian == account) {
                revert InvalidGuardianAddress();
            }

            // As long as weights are 1 or above, there will be enough total weight to reach the
            // required threshold. This is because we check the guardian count cannot be less
            // than the threshold and there is an equal amount of guardians to weights.
            if (weight == 0) {
                revert InvalidGuardianWeight();
            }

            GuardianStorage memory guardianStorage = guardiansStorage[account].get(guardian);
            if (guardianStorage.status != GuardianStatus.NONE) {
                revert AddressAlreadyGuardian();
            }

            guardiansStorage[account].set({
                key: guardian,
                value: GuardianStorage(GuardianStatus.REQUESTED, weight)
            });
            totalWeight += weight;
        }

        if (threshold > totalWeight) {
            revert ThresholdExceedsTotalWeight();
        }

        guardianConfigs[account] = IEmailRecoveryManager.GuardianConfig({
            guardianCount: guardianCount,
            totalWeight: totalWeight,
            acceptedWeight: 0,
            threshold: threshold
        });
    }

    /**
     * @notice Updates the status for a guardian
     * @param account The address of the account associated with the guardian
     * @param guardian The address of the guardian
     * @param newStatus The new status for the guardian
     */
    function updateGuardianStatus(
        mapping(address => EnumerableGuardianMap.AddressToGuardianMap) storage guardiansStorage,
        address account,
        address guardian,
        GuardianStatus newStatus
    )
        internal
    {
        GuardianStorage memory guardianStorage = guardiansStorage[account].get(guardian);
        if (newStatus == guardianStorage.status) {
            revert StatusCannotBeTheSame();
        }

        guardiansStorage[account].set({
            key: guardian,
            value: GuardianStorage(newStatus, guardianStorage.weight)
        });
    }

    /**
     * @notice Adds a guardian for the caller's account with a specified weight
     * @dev A guardian is added, but not accepted after this function has been called
     * @param guardianConfigs The guardian config storage associated with an account
     * @param account The address of the account associated with the guardian
     * @param guardian The address of the guardian to be added
     * @param weight The weight assigned to the guardian
     */
    function addGuardian(
        mapping(address => EnumerableGuardianMap.AddressToGuardianMap) storage guardiansStorage,
        mapping(address => IEmailRecoveryManager.GuardianConfig) storage guardianConfigs,
        address account,
        address guardian,
        uint256 weight
    )
        internal
    {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function should be called first
        if (guardianConfigs[account].threshold == 0) {
            revert SetupNotCalled();
        }

        if (guardian == address(0) || guardian == account) {
            revert InvalidGuardianAddress();
        }

        GuardianStorage memory guardianStorage = guardiansStorage[account].get(guardian);

        if (guardianStorage.status != GuardianStatus.NONE) {
            revert AddressAlreadyGuardian();
        }

        if (weight == 0) {
            revert InvalidGuardianWeight();
        }

        guardiansStorage[account].set({
            key: guardian,
            value: GuardianStorage(GuardianStatus.REQUESTED, weight)
        });
        guardianConfigs[account].guardianCount++;
        guardianConfigs[account].totalWeight += weight;

        emit AddedGuardian(account, guardian);
    }

    /**
     * @notice Removes a guardian for the caller's account
     * @param guardianConfigs The guardian config storage associated with an account
     * @param account The address of the account associated with the guardian
     * @param guardian The address of the guardian to be removed
     */
    function removeGuardian(
        mapping(address => EnumerableGuardianMap.AddressToGuardianMap) storage guardiansStorage,
        mapping(address => IEmailRecoveryManager.GuardianConfig) storage guardianConfigs,
        address account,
        address guardian
    )
        internal
    {
        IEmailRecoveryManager.GuardianConfig memory guardianConfig = guardianConfigs[account];
        GuardianStorage memory guardianStorage = guardiansStorage[account].get(guardian);

        bool isGuardian = guardianStorage.status != GuardianStatus.NONE;
        if (!isGuardian) {
            revert UnauthorizedAccountForGuardian();
        }

        // Only allow guardian removal if threshold can still be reached.
        if (guardianConfig.totalWeight - guardianStorage.weight < guardianConfig.threshold) {
            revert ThresholdExceedsTotalWeight();
        }

        guardiansStorage[account].remove(guardian);
        guardianConfigs[account].guardianCount--;
        guardianConfigs[account].totalWeight -= guardianStorage.weight;
        if (guardianStorage.status == GuardianStatus.ACCEPTED) {
            guardianConfigs[account].acceptedWeight -= guardianStorage.weight;
        }

        emit RemovedGuardian(account, guardian);
    }

    /**
     * @notice Removes all guardians associated with an account
     * @dev Does not remove guardian config, this should be modified at the same time as calling
     * this function
     * @param account The address of the account associated with the guardians
     */
    function removeAllGuardians(
        mapping(address => EnumerableGuardianMap.AddressToGuardianMap) storage guardiansStorage,
        address account
    )
        internal
    {
        guardiansStorage[account].removeAll(guardiansStorage[account].keys());
    }

    /**
     * @notice Changes the threshold for guardian approvals for the caller's account
     * @param account The address of the account associated with the guardians
     * @param threshold The new threshold for guardian approvals
     */
    function changeThreshold(
        mapping(address => IEmailRecoveryManager.GuardianConfig) storage guardianConfigs,
        address account,
        uint256 threshold
    )
        internal
    {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function should be called first
        if (guardianConfigs[account].threshold == 0) {
            revert SetupNotCalled();
        }

        // Validate that threshold is smaller than the total weight.
        if (threshold > guardianConfigs[account].totalWeight) {
            revert ThresholdExceedsTotalWeight();
        }

        // Guardian weight should be at least 1
        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }

        guardianConfigs[account].threshold = threshold;
        emit ChangedThreshold(account, threshold);
    }
}
