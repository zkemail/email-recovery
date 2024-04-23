// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZkEmailRecovery {
    struct RecoveryRequest {
        uint256 executeAfter; // the timestamp from which the recovery request can be executed
        uint256 approvalCount; // number of guardian approvals for the recovery request
        bytes recoveryData; // the data required to execute the recovery request. This may include data such as the new owner.
    }

    /** Errors */
    error ModuleNotEnabled();
    error InvalidOwner(address owner);
    error InvalidGuardian();
    error InvalidTemplateIndex();
    error InvalidSubjectParams();
    error InvalidNewOwner();
    error InvalidAccountForRouter();
    error GuardianInvalidForAccountInEmail();
    error GuardianAlreadyAccepted();
    error GuardianHasNotAccepted();
    error RecoveryAlreadyInitiated();
    error RecoveryNotInitiated();
    error NotEnoughApprovals();
    error DelayNotPassed();

    /** Events */
    event RecoveryConfigured(
        address indexed account,
        uint256 guardianCount,
        uint256 threshold,
        uint256 recoveryDelay,
        address router
    );
    event RecoveryInitiated(
        address indexed account,
        address newOwner,
        uint256 executeAfter
    );
    event OwnerRecovered(
        address indexed account,
        address oldOwner,
        address newOwner
    );
    event RecoveryCancelled(address indexed account);

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
    function getRecoveryDelay(address account) external view returns (uint256);

    /**
     * @notice Cancels the recovery process of the sender if it exits.
     * @dev Deletes the recovery request accociated with a account. Assumes
     *      the msg.sender is the account that the recovery request is being deleted for
     */
    function cancelRecovery() external;

    // TODO: add natspec
    function updateRecoveryDelay(uint256 recoveryDelay) external;
}
