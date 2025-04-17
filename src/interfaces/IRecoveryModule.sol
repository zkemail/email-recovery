// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IRecoveryModule {
    event RecoveryConfigured(
        address indexed account,
        address indexed validator,
        uint256 guardianCount,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    );
    event AddedGuardian(
        address indexed account,
        address indexed validator,
        address guardian
    );
    event RecoveryRequestStarted(
        address indexed account,
        address indexed validator,
        uint256 executeBefore,
        bytes32 recoveryDataHash
    );
    event GuardianVoted(
        address indexed account,
        address indexed validator,
        address indexed guardian,
        uint256 approvals
    );
    event RecoveryRequestComplete(
        address indexed account,
        address indexed validator,
        uint256 executeAfter,
        uint256 executeBefore,
        bytes32 recoveryDataHash
    );
    event RecoveryExecuted(address indexed account, address indexed validator);

    error ThresholdCannotBeZero();
    error InvalidGuardianAddress(address guardian);
    error ThresholdExceedsGuardianCount(
        uint256 threshold,
        uint256 guardianCount
    );
    error DelayMoreThanExpiry(uint256 delay, uint256 expiry);
    error RecoveryWindowTooShort(uint256 recoveryWindow);
    error RecoveryInProcess();
    error NoRecoveryConfigured();
    error GuardianAlreadyVoted();
    error InvalidGuardianSignature();
    error InvalidRecoveryDataHash(bytes32 hash, bytes32 recoveryDataHash);
    error InvalidAccountAddress();
    error NotEnoughApprovals(uint256 approvals, uint256 threshold);
    error DelayNotPassed(uint256 timestamp, uint256 executeAfter);
    error RecoveryRequestExpired(uint256 timestamp, uint256 executeBefore);

    /**
     * @notice Retrieves the recovery configuration for a given account and module
     * @param account The account
     * @param module The module to recover
     */
    function getRecoveryConfig(
        address account,
        address module
    )
        external
        view
        returns (
            address[] memory guardians,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        );

    /**
     * @notice Retrieves the recovery request details for a given account and module
     * @dev Does not return guardianVoted as that is part of a nested mapping
     * @param account The address of the account for which the recovery request details are being
     * retrieved
     */
    function getRecoveryRequest(
        address account,
        address module
    )
        external
        view
        returns (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 approvals,
            bytes32 recoveryDataHash
        );

    /**
     * @notice Initiates a recovery for a given account
     * @dev called once per guardian
     * @param account The account
     * @param module The module to recover
     * @param signature Signature/proof of guardian authentication
     * @param hash The recovery calldata hash
     */
    function approveRecovery(
        address account,
        address module,
        address guardian,
        bytes memory signature,
        bytes32 hash
    ) external;

    /**
     * @notice Completes the recovery flow for a given account
     * @param account The account to recovery
     * @param recoveryCalldata Data needed to finalize the recovery
     */
    function executeRecovery(
        address account,
        address module,
        bytes calldata recoveryCalldata
    ) external;

    /**
     * @notice Cancels an ongoing recovery request for a given account
     * @param account The account
     * @param module The module to recover
     */
    function cancelRecovery(address account, address module) external;
}
