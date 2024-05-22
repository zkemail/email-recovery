// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZkEmailRecovery {
    struct RecoveryConfig {
        uint256 delay; // the time from when recovery is started until the recovery request can be executed
        uint256 expiry; // the time from when recovery is started until the recovery request becomes invalid
    }
    struct RecoveryRequest {
        uint256 executeAfter; // the timestamp from which the recovery request can be executed
        uint256 executeBefore; // the timestamp from which the recovery request becomes invalid
        uint256 totalWeight; // total weight of all guardian approvals for the recovery request
        address newOwner;
        address recoveryModule; // the trusted recovery module that has permission to recover an account
    }

    enum GuardianStatus {
        NONE,
        REQUESTED,
        ACCEPTED
    }

    struct GuardianStorage {
        GuardianStatus status;
        uint256 weight;
    }

    struct GuardianConfig {
        uint256 guardianCount;
        uint256 threshold;
    }

    /** Errors */
    error InvalidGuardian();
    error InvalidRecoveryModule();
    error InvalidNewOwner();
    error InvalidTemplateIndex();
    error InvalidSubjectParams();
    error InvalidGuardianStatus(
        GuardianStatus guardianStatus,
        GuardianStatus expectedGuardianStatus
    );
    error RecoveryInProcess();
    error NotEnoughApprovals();
    error DelayNotPassed();
    error RecoveryRequestExpired();

    error DelayLessThanExpiry();
    error RecoveryWindowTooShort();

    /** Guardian logic errors */
    error SetupAlreadyCalled();
    error IncorrectNumberOfWeights();
    error ThresholdCannotExceedGuardianCount();
    error ThresholdCannotBeZero();
    error InvalidAccountAddress();
    error InvalidGuardianAddress();
    error InvalidGuardianWeight();
    error AccountNotConfigured();
    error AddressAlreadyRequested();
    error AddressAlreadyGuardian();
    error GuardianStatusMustBeDifferent();

    /** Router errors */
    error RouterAlreadyDeployed();

    /** Events */
    event RecoveryConfigured(
        address indexed account,
        uint256 delay,
        uint256 expiry,
        address router
    );
    event RecoveryInitiated(address indexed account, uint256 executeAfter);
    event RecoveryCompleted(address indexed account);
    event RecoveryCancelled(address indexed account);

    /** Guardian logic events  */
    event AddedGuardian(address indexed guardian);
    event RemovedGuardian(address indexed guardian);
    event ChangedThreshold(uint256 threshold);

    /** Functions */

    /**
     * @notice Returns recovery request accociated with a account address
     * @param account address to query storage with
     */
    function getRecoveryRequest(
        address account
    ) external view returns (RecoveryRequest memory);

    /**
     * @notice Returns the recovery delay that corresponds to the specified account
     * @param account address to query storage with
     */
    function getRecoveryConfig(
        address account
    ) external view returns (RecoveryConfig memory);

    function configureRecovery(
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    ) external;

    /**
     * @notice Cancels the recovery process of the sender if it exits.
     * @dev Deletes the recovery request accociated with a account. Assumes
     *      the msg.sender is the account that the recovery request is being deleted for
     */
    function cancelRecovery(bytes calldata data) external;

    // TODO: add natspec
    function updateRecoveryConfig(
        RecoveryConfig calldata recoveryConfig
    ) external;

    /*//////////////////////////////////////////////////////////////////////////
                                GUARDIAN LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates the guardian `guardian` for the Account.
     * @dev TODO: comment on access control
     * @param guardian Guardian address to be remoupdatedved.
     * @param guardianStorage guardian storage struct.
     */
    function updateGuardian(
        address guardian,
        GuardianStorage memory guardianStorage
    ) external;

    /**
     * @notice Adds the guardian `guardian` to the Account and updates the threshold to `_threshold`.
     * @dev TODO: comment on access control
     * @param guardian New guardian address.
     * @param weight New weight.
     * @param _threshold New threshold.
     */
    function addGuardianWithThreshold(
        address guardian,
        uint256 weight,
        uint256 _threshold
    ) external;

    /**
     * @notice Removes the guardian `guardian` from the Account and updates the threshold to `_threshold`.
     * @dev TODO: comment on access control
     * @param guardian Guardian address to be removed.
     * @param _threshold New threshold.
     */
    function removeGuardian(address guardian, uint256 _threshold) external;

    /**
     * @notice Replaces the guardian `oldGuardian` in the Account with `newGuardian`.
     * @dev TODO: comment on access control
     * @param oldGuardian Guardian address to be replaced.
     * @param newGuardian New guardian address.
     */
    function swapGuardian(address oldGuardian, address newGuardian) external;

    /**
     * @notice Changes the threshold of the Account to `_threshold`.
     * @dev TODO: comment on access control
     * @param _threshold New threshold.
     */
    function changeThreshold(uint256 _threshold) external;

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
    function getGuardian(
        address account,
        address guardian
    ) external view returns (GuardianStorage memory);

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

    /*//////////////////////////////////////////////////////////////////////////
                                ROUTER LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function getAccountForRouter(
        address recoveryRouter
    ) external view returns (address);

    function getRouterForAccount(
        address account
    ) external view returns (address);
}
