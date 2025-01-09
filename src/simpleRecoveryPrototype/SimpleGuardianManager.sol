// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EnumerableGuardianMap, GuardianStorage, GuardianStatus } from "../libraries/EnumerableGuardianMap.sol";
import { ISimpleRecoveryModuleManager } from "./interfaces/ISimpleRecoveryModuleManager.sol";
import { ISimpleGuardianManager } from "./interfaces/ISimpleGuardianManager.sol";

/**
 * @title GuardianManager
 * @notice A contract to manage guardians
 */
abstract contract SimpleGuardianManager is ISimpleGuardianManager {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    /**
     * @notice Account to guardian configuration
     */
    mapping(address account => SimpleGuardianManager.GuardianConfig guardianConfig)
        internal guardianConfigs;

    /**
     * @notice Account address to guardian storage map
     */
    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian)
        internal guardiansStorage;

    /**
     * @notice Account to guardian address to guardian type
     */
    mapping(address => mapping(address => GuardianType)) public guardianTypes;

    /**
     * @notice Modifier to check recovery status. Reverts if recovery is in process for the account.
     */
    modifier onlyWhenNotRecovering() {
        (, , uint256 currentWeight, ) = ISimpleRecoveryModuleManager(address(this))
            .getRecoveryRequest(msg.sender);
        if (currentWeight > 0) {
            revert RecoveryInProcess();
        }
        _;
    }

    /**
     * @notice Modifier to check if the kill switch has been enabled
     */
    modifier onlyWhenActive() {
        bool killSwitchEnabled = ISimpleRecoveryModuleManager(address(this)).killSwitchEnabled();
        if (killSwitchEnabled) {
            revert KillSwitchEnabled();
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       GUARDIAN LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves the guardian configuration for a given account.
     * @param account The address of the account.
     * @return GuardianConfig The guardian configuration for the specified account.
     */
    function getGuardianConfig(address account) public view returns (GuardianConfig memory) {
        return guardianConfigs[account];
    }

    /**
     * @notice Retrieves the guardian storage details for a given guardian and account.
     * @param account The address of the account associated with the guardian.
     * @param guardian The address of the guardian.
     * @return GuardianStorage The guardian storage details.
     */
    function getGuardian(address account, address guardian) public view returns (GuardianStorage memory) {
        return guardiansStorage[account].get(guardian);
    }

    /**
     * @notice Sets up guardians for an account with specified weights and threshold.
     * @param account The account address.
     * @param guardians An array of guardian addresses.
     * @param weights An array of weights corresponding to each guardian.
     * @param guardiantypes An array of guardian types.
     * @param threshold The threshold weight required for recovery.
     */
    function setupGuardians(
        address account,
        address[] memory guardians,
        uint256[] memory weights,
        GuardianType[] memory guardiantypes,
        uint256 threshold
    ) internal returns (uint256, uint256) {
        uint256 guardianCount = guardians.length;

        if (guardianCount != weights.length) {
            revert IncorrectNumberOfWeights(guardianCount, weights.length);
        }

        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }

        for (uint256 i = 0; i < guardianCount; i++) {
            _addGuardian(account, guardians[i], weights[i], guardiantypes[i]);
        }

        uint256 totalWeight = guardianConfigs[account].totalWeight;
        if (threshold > totalWeight) {
            revert ThresholdExceedsTotalWeight(threshold, totalWeight);
        }

        guardianConfigs[account].threshold = threshold;
        return (guardianCount, totalWeight);
    }

    /**
     * @notice Adds a guardian for the caller's account.
     * @param guardian The address of the guardian.
     * @param weight The weight assigned to the guardian.
     * @param guardianType The type of the guardian.
     */
    function addGuardian(
        address guardian,
        uint256 weight,
        GuardianType guardianType
    ) public onlyWhenNotRecovering {
        if (guardianConfigs[msg.sender].threshold == 0) {
            revert SetupNotCalled();
        }

        _addGuardian(msg.sender, guardian, weight, guardianType);
    }

    /**
     * @notice Internal function to add a guardian with specified weight.
     * @param account The account address.
     * @param guardian The guardian address.
     * @param weight The weight assigned to the guardian.
     * @param guardianType The type of the guardian.
     */
    function _addGuardian(address account, address guardian, uint256 weight, GuardianType guardianType) internal {
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

        guardianTypes[account][guardian] = guardianType;

        guardianConfigs[account].guardianCount++;
        guardianConfigs[account].totalWeight += weight;

        emit AddedGuardian(account, guardian, weight, guardianType);
    }

    /**
     * @notice Removes a guardian for the caller's account.
     * @param guardian The address of the guardian to be removed.
     */
    function removeGuardian(address guardian) external onlyWhenNotRecovering {
        GuardianConfig memory guardianConfig = guardianConfigs[msg.sender];
        GuardianStorage memory guardianStorage = guardiansStorage[msg.sender].get(guardian);

        bool success = guardiansStorage[msg.sender].remove(guardian);
        if (!success) {
            revert AddressNotGuardianForAccount();
        }

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
     * @notice Changes the threshold for guardian approvals for the caller's account.
     * @param threshold The new threshold for guardian approvals.
     */
    function changeThreshold(uint256 threshold) external onlyWhenNotRecovering {
        if (guardianConfigs[msg.sender].threshold == 0) {
            revert SetupNotCalled();
        }

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
     * @notice Updates the status for a guardian.
     * @param account The account address.
     * @param guardian The guardian address.
     * @param newStatus The new status for the guardian.
     */
    function updateGuardianStatus(
        address account,
        address guardian,
        GuardianStatus newStatus
    ) internal {
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
}
