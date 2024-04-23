// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {IGuardianManager} from "./interfaces/IGuardianManager.sol";

abstract contract GuardianManager is IGuardianManager {
    /** Account to guardian to guardian status */
    mapping(address => mapping(address => GuardianStatus)) internal guardians;

    /** Account to guardian storage */
    mapping(address => GuardianConfig) internal guardianConfigs;

    /**
     * @notice Sets the initial storage of the contract.
     * @param account The account.
     * @param _guardians List of account guardians.
     * @param threshold Number of required confirmations for successful recovery request.
     */
    function setupGuardians(
        address account,
        address[] memory _guardians,
        uint256 threshold
    ) internal {
        uint256 guardianCount = _guardians.length;
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        if (guardianConfigs[account].threshold > 0) revert SetupAlreadyCalled();

        // Validate that threshold is smaller than number of added owners.
        if (threshold > guardianCount)
            revert ThresholdCannotExceedGuardianCount();

        // There has to be at least one Account owner.
        if (threshold == 0) revert ThresholdCannotBeZero();

        for (uint256 i = 0; i < guardianCount; i++) {
            address guardian = _guardians[i];
            GuardianStatus guardianStatus = guardians[account][guardian];

            if (guardian == address(0) || guardian == address(this))
                revert InvalidGuardianAddress();

            if (guardianStatus == GuardianStatus.REQUESTED)
                revert AddressAlreadyRequested();

            if (guardianStatus == GuardianStatus.ACCEPTED)
                revert AddressAlreadyGuardian();

            guardians[account][guardian] = GuardianStatus.REQUESTED;
        }

        guardianConfigs[account] = GuardianConfig(guardianCount, threshold);
    }

    // @inheritdoc IGuardianManager
    // FIXME: replace authorized modifier with proper access control
    function updateGuardian(
        address account,
        address guardian,
        GuardianStatus guardianStatus
    ) public override {
        if (account == address(0) || account == address(this))
            revert InvalidAccountAddress();

        if (guardian == address(0) || guardian == address(this))
            revert InvalidGuardianAddress();

        GuardianStatus oldGuardianStatus = guardians[account][guardian];
        if (guardianStatus == oldGuardianStatus)
            revert GuardianStatusMustBeDifferent();

        guardians[account][guardian] = guardianStatus;
    }

    // @inheritdoc IGuardianManager
    // FIXME: replace authorized modifier with proper access control
    function addGuardianWithThreshold(
        address guardian,
        uint256 threshold,
        address account
    ) public override {
        GuardianStatus guardianStatus = guardians[account][guardian];

        // Guardian address cannot be null, the sentinel or the Account itself.
        if (guardian == address(0) || guardian == address(this))
            revert InvalidGuardianAddress();

        if (guardianStatus == GuardianStatus.REQUESTED)
            revert AddressAlreadyRequested();

        if (guardianStatus == GuardianStatus.ACCEPTED)
            revert AddressAlreadyGuardian();

        guardians[account][guardian] = GuardianStatus.REQUESTED;
        guardianConfigs[account].guardianCount++;

        emit AddedGuardian(guardian);

        // Change threshold if threshold was changed.
        if (guardianConfigs[account].threshold != threshold)
            changeThreshold(threshold, account);
    }

    // @inheritdoc IGuardianManager
    // FIXME: replace authorized modifier with proper access control
    function removeGuardian(
        address guardian,
        uint256 threshold,
        address account
    ) public override {
        // Only allow to remove an guardian, if threshold can still be reached.
        if (guardianConfigs[account].threshold - 1 < threshold)
            revert ThresholdCannotExceedGuardianCount();

        if (guardian == address(0)) revert InvalidGuardianAddress();

        guardians[account][guardian] = GuardianStatus.NONE;
        guardianConfigs[account].guardianCount--;

        emit RemovedGuardian(guardian);

        // Change threshold if threshold was changed.
        if (guardianConfigs[account].threshold != threshold)
            changeThreshold(threshold, account);
    }

    // @inheritdoc IGuardianManager
    // FIXME: replace authorized modifier with proper access control
    function swapGuardian(
        address oldGuardian,
        address newGuardian,
        address account
    ) public override {
        GuardianStatus newGuardianStatus = guardians[account][newGuardian];

        if (
            newGuardian == address(0) ||
            newGuardian == address(this) ||
            newGuardian == oldGuardian
        ) revert InvalidGuardianAddress();

        if (newGuardianStatus == GuardianStatus.REQUESTED)
            revert AddressAlreadyRequested();

        if (newGuardianStatus == GuardianStatus.ACCEPTED)
            revert AddressAlreadyGuardian();

        GuardianStatus oldGuardianStatus = guardians[account][oldGuardian];

        if (oldGuardian == address(0)) revert InvalidGuardianAddress();

        if (oldGuardianStatus == GuardianStatus.REQUESTED)
            revert AddressAlreadyRequested();

        guardians[account][newGuardian] = GuardianStatus.REQUESTED;
        guardians[account][oldGuardian] = GuardianStatus.NONE;

        emit RemovedGuardian(oldGuardian);
        emit AddedGuardian(newGuardian);
    }

    // @inheritdoc IGuardianManager
    // FIXME: replace authorized modifier with proper access control
    function changeThreshold(
        uint256 threshold,
        address account
    ) public override {
        // Validate that threshold is smaller than number of guardians.
        if (threshold > guardianConfigs[account].guardianCount)
            revert ThresholdCannotExceedGuardianCount();

        // There has to be at least one Account guardian.
        if (threshold == 0) revert ThresholdCannotBeZero();

        guardianConfigs[account].threshold = threshold;
        emit ChangedThreshold(threshold);
    }

    // @inheritdoc IGuardianManager
    function getGuardianConfig(
        address account
    ) public view override returns (GuardianConfig memory) {
        return guardianConfigs[account];
    }

    // @inheritdoc IGuardianManager
    function getGuardianStatus(
        address account,
        address guardian
    ) public view returns (GuardianStatus) {
        return guardians[account][guardian];
    }

    // @inheritdoc IGuardianManager
    function isGuardian(
        address guardian,
        address account
    ) public view override returns (bool) {
        return guardians[account][guardian] != GuardianStatus.NONE;
    }
}
