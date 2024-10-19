// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "./libraries/EnumerableGuardianMap.sol";
import { IEmailRecoveryManager } from "./interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "./interfaces/IGuardianManager.sol";

/**
 * @title GuardianManager
 * @notice A contract to manage guardians
 */
abstract contract GuardianManager is IGuardianManager {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    /**
     * Account to guardian config
     */
    mapping(address account => GuardianManager.GuardianConfig guardianConfig) internal
        guardianConfigs;

    /**
     * Account address to guardian address to guardian storage
     */
    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    /**
     * @notice Modifier to check recovery status. Reverts if recovery is in process for the account
     */
    modifier onlyWhenNotRecovering() {
        (,, uint256 currentWeight,) =
            IEmailRecoveryManager(address(this)).getRecoveryRequest(msg.sender);
        if (currentWeight > 0) {
            revert RecoveryInProcess();
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       GUARDIAN LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves the guardian configuration for a given account
     * @param account The address of the account for which the guardian configuration is being
     * retrieved
     * @return GuardianConfig The guardian configuration for the specified account
     */
    function getGuardianConfig(address account) public view returns (GuardianConfig memory) {
        return guardianConfigs[account];
    }

    /**
     * @notice Retrieves the guardian storage details for a given guardian and account
     * @param account The address of the account associated with the guardian
     * @param guardian The address of the guardian
     * @return GuardianStorage The guardian storage details for the specified guardian and account
     */
    function getGuardian(
        address account,
        address guardian
    )
        public
        view
        returns (GuardianStorage memory)
    {
        return guardiansStorage[account].get(guardian);
    }

    /**
     * @notice Sets up guardians for a given account with specified weights and threshold
     * @dev This function can only be called once and ensures the guardians, weights, and threshold
     * are correctly configured
     * @param account The address of the account for which guardians are being set up
     * @param guardians An array of guardian addresses
     * @param weights An array of weights corresponding to each guardian
     * @param threshold The threshold weight required for guardians to approve recovery attempts
     */
    function setupGuardians(
        address account,
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold
    )
        internal
        returns (uint256, uint256)
    {
        uint256 guardianCount = guardians.length;

        if (guardianCount != weights.length) {
            revert IncorrectNumberOfWeights(guardianCount, weights.length);
        }

        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }

        for (uint256 i = 0; i < guardianCount; i++) {
            _addGuardian(account, guardians[i], weights[i]);
        }

        uint256 totalWeight = guardianConfigs[account].totalWeight;
        if (threshold > totalWeight) {
            revert ThresholdExceedsTotalWeight(threshold, totalWeight);
        }

        guardianConfigs[account].threshold = threshold;

        return (guardianCount, totalWeight);
    }

    /**
     * @notice Adds a guardian for the caller's account with a specified weight
     * @dev This function can only be called by the account associated with the guardian and only if
     * no recovery is in process
     * @param guardian The address of the guardian to be added
     * @param weight The weight assigned to the guardian
     */
    function addGuardian(address guardian, uint256 weight) public onlyWhenNotRecovering {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function should be called first
        if (guardianConfigs[msg.sender].threshold == 0) {
            revert SetupNotCalled();
        }

        _addGuardian(msg.sender, guardian, weight);
    }

    /**
     * @notice Internal fucntion to add a guardian for the caller's account with a specified weight
     * @dev A guardian is added, but not accepted after this function has been called
     * @param guardian The address of the guardian to be added
     * @param weight The weight assigned to the guardian
     */
    function _addGuardian(address account, address guardian, uint256 weight) internal {
        if (guardian == address(0) || guardian == account) {
            revert InvalidGuardianAddress(guardian);
        }

        if (weight == 0) {
            revert InvalidGuardianWeight();
        }

        bool success = guardiansStorage[account].set({
            key: guardian,
            value: GuardianStorage(GuardianStatus.REQUESTED, weight)
        });
        if (!success) {
            revert AddressAlreadyGuardian();
        }

        guardianConfigs[account].guardianCount++;
        guardianConfigs[account].totalWeight += weight;

        emit AddedGuardian(account, guardian, weight);
    }

    /**
     * @notice Removes a guardian for the caller's account
     * @dev This function can only be called by the account associated with the guardian and only if
     * no recovery is in process
     * @param guardian The address of the guardian to be removed
     */
    function removeGuardian(address guardian) external onlyWhenNotRecovering {
        GuardianConfig memory guardianConfig = guardianConfigs[msg.sender];
        GuardianStorage memory guardianStorage = guardiansStorage[msg.sender].get(guardian);

        bool success = guardiansStorage[msg.sender].remove(guardian);
        if (!success) {
            // false means that the guardian was not present in the map. This serves as a proxy that
            // the account is not authorized to remove this guardian
            revert AddressNotGuardianForAccount();
        }

        // Only allow guardian removal if threshold can still be reached.
        uint256 newTotalWeight = guardianConfig.totalWeight - guardianStorage.weight;
        if (newTotalWeight < guardianConfig.threshold) {
            revert ThresholdExceedsTotalWeight(newTotalWeight, guardianConfig.threshold);
        }

        guardianConfigs[msg.sender].guardianCount--;
        guardianConfigs[msg.sender].totalWeight -= guardianStorage.weight;
        if (guardianStorage.status == GuardianStatus.ACCEPTED) {
            guardianConfigs[msg.sender].acceptedWeight -= guardianStorage.weight;
        }

        emit RemovedGuardian(msg.sender, guardian, guardianStorage.weight);
    }

    /**
     * @notice Changes the threshold for guardian approvals for the caller's account
     * @dev This function can only be called by the account associated with the guardian config and
     * only if no recovery is in process
     * @param threshold The new threshold for guardian approvals
     */
    function changeThreshold(uint256 threshold) external onlyWhenNotRecovering {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function should be called first
        if (guardianConfigs[msg.sender].threshold == 0) {
            revert SetupNotCalled();
        }

        // Validate that threshold is smaller than the total weight.
        if (threshold > guardianConfigs[msg.sender].totalWeight) {
            revert ThresholdExceedsTotalWeight(threshold, guardianConfigs[msg.sender].totalWeight);
        }

        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }

        guardianConfigs[msg.sender].threshold = threshold;
        emit ChangedThreshold(msg.sender, threshold);
    }

    /**
     * @notice Updates the status for a guardian
     * @param account The address of the account associated with the guardian
     * @param guardian The address of the guardian
     * @param newStatus The new status for the guardian
     */
    function updateGuardianStatus(
        address account,
        address guardian,
        GuardianStatus newStatus
    )
        internal
    {
        GuardianStorage memory guardianStorage = guardiansStorage[account].get(guardian);
        if (newStatus == guardianStorage.status) {
            revert StatusCannotBeTheSame(newStatus);
        }

        guardiansStorage[account].set({
            key: guardian,
            value: GuardianStorage(newStatus, guardianStorage.weight)
        });
        emit GuardianStatusUpdated(account, guardian, newStatus);
    }

    /**
     * @notice Removes all guardians associated with an account
     * @dev Does not remove guardian config, this should be modified at the same time as calling
     * this function
     * @param account The address of the account associated with the guardians
     */
    function removeAllGuardians(address account) internal {
        guardiansStorage[account].removeAll(guardiansStorage[account].keys());
    }

    /**
     * @notice Gets all guardians associated with an account
     * @dev Return an array containing all the keys. O(n) where n <= 32
     *
     * WARNING: This operation will copy the entire storage to memory, which could
     * be quite expensive.
     * @param account The address of the account associated with the guardians
     */
    function getAllGuardians(address account) external view returns (address[] memory) {
        return guardiansStorage[account].keys();
    }
}
