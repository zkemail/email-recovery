// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

/**
 * @title IGuardianManager - Interface for contract which manages Account zk email recovery plugin guardians and a threshold to authorize recovery attempts.
 */
interface IGuardianManager {
    enum GuardianStatus {
        NONE,
        REQUESTED,
        ACCEPTED
    }

    struct GuardianConfig {
        uint256 guardianCount;
        uint256 threshold;
    }

    error SetupAlreadyCalled();
    error ThresholdCannotExceedGuardianCount();
    error ThresholdCannotBeZero();
    error InvalidAccountAddress();
    error InvalidGuardianAddress();
    error AddressAlreadyRequested();
    error AddressAlreadyGuardian();
    error GuardianStatusMustBeDifferent();

    event AddedGuardian(address indexed guardian);
    event RemovedGuardian(address indexed guardian);
    event ChangedThreshold(uint256 threshold);

    /**
     * @notice Updates the guardian `guardian` for the Account.
     * @dev TODO: comment on access control
     * @param account The Account account that the guardians should recover.
     * @param guardian Guardian address to be remoupdatedved.
     * @param guardianStatus enum.
     */
    function updateGuardian(
        address account,
        address guardian,
        GuardianStatus guardianStatus
    ) external;

    /**
     * @notice Adds the guardian `guardian` to the Account and updates the threshold to `_threshold`.
     * @dev TODO: comment on access control
     * @param guardian New guardian address.
     * @param _threshold New threshold.
     * @param account The Account account that the guardians should recover.
     */
    function addGuardianWithThreshold(
        address guardian,
        uint256 _threshold,
        address account
    ) external;

    /**
     * @notice Removes the guardian `guardian` from the Account and updates the threshold to `_threshold`.
     * @dev TODO: comment on access control
     * @param guardian Guardian address to be removed.
     * @param _threshold New threshold.
     * @param account The Account account that the guardians should recover.
     */
    function removeGuardian(
        address guardian,
        uint256 _threshold,
        address account
    ) external;

    /**
     * @notice Replaces the guardian `oldGuardian` in the Account with `newGuardian`.
     * @dev TODO: comment on access control
     * @param oldGuardian Guardian address to be replaced.
     * @param newGuardian New guardian address.
     * @param account The Account account that the guardians should recover.
     */
    function swapGuardian(
        address oldGuardian,
        address newGuardian,
        address account
    ) external;

    /**
     * @notice Changes the threshold of the Account to `_threshold`.
     * @dev TODO: comment on access control
     * @param _threshold New threshold.
     * @param account The Account account that the guardians should recover.
     */
    function changeThreshold(uint256 _threshold, address account) external;

    /**
     * @notice Returns the number of required confirmations for a Account transaction aka the threshold.
     * @param account The Account account that the guardians should recover.
     * @return Threshold number.
     */
    function getGuardianConfig(
        address account
    ) external view returns (GuardianConfig memory);

    /**
     * @notice Returns the status of the guardian for the account
     * @param account The Account account that the guardians should recover.
     * @param guardian The guardian to query the status for.
     * @return GuardianStatus enum.
     */
    function getGuardianStatus(
        address account,
        address guardian
    ) external view returns (GuardianStatus);

    /**
     * @notice Returns if `guardian` is an guardian of the Account.
     * @param guardian The guardian address that is being checked.
     * @param account The Account account that the guardians should recover.
     * @return Boolean if guardian is an guardian of the Account.
     */
    function isGuardian(
        address guardian,
        address account
    ) external view returns (bool);
}
