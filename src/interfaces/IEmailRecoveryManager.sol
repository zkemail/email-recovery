// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { GuardianStatus } from "../libraries/EnumerableGuardianMap.sol";

interface IEmailRecoveryManager {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     TYPE DELARATIONS                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * A struct representing the values required for recovery configuration
     * Config should be maintained over subsequent recovery attempts unless explicitly modified
     */
    struct RecoveryConfig {
        uint256 delay; // the time from when recovery is started until the recovery request can be
        // executed
        uint256 expiry; // the time from when recovery is started until the recovery request becomes
            // invalid. The recovery expiry encourages the timely execution of successful recovery
            // attempts, and reduces the risk of unauthorized access through stale or outdated
            // requests.
    }

    /**
     * A struct representing the values required for a recovery request
     * The request state should be maintained over a single recovery attempts unless
     * explicitly modified. It should be deleted after a recovery attempt has been processed
     */
    struct RecoveryRequest {
        uint256 executeAfter; // the timestamp from which the recovery request can be executed
        uint256 executeBefore; // the timestamp from which the recovery request becomes invalid
        uint256 currentWeight; // total weight of all guardian approvals for the recovery request
        bytes32 recoveryDataHash; // the keccak256 hash of the recovery data used to execute the
            // recovery attempt.
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event RecoveryConfigured(
        address indexed account, uint256 guardianCount, uint256 totalWeight, uint256 threshold
    );
    event RecoveryConfigUpdated(address indexed account, uint256 delay, uint256 expiry);
    event GuardianAccepted(address indexed account, address indexed guardian);
    event RecoveryProcessed(
        address indexed account,
        address indexed guardian,
        uint256 executeAfter,
        uint256 executeBefore,
        bytes32 recoveryDataHash
    );
    event RecoveryCompleted(address indexed account);
    event RecoveryCancelled(address indexed account);
    event RecoveryDeInitialized(address indexed account);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InvalidVerifier();
    error InvalidDkimRegistry();
    error InvalidEmailAuthImpl();
    error InvalidSubjectHandler();
    error SetupAlreadyCalled();
    error AccountNotConfigured();
    error DelayMoreThanExpiry(uint256 delay, uint256 expiry);
    error RecoveryWindowTooShort(uint256 recoveryWindow);
    error ThresholdExceedsAcceptedWeight(uint256 threshold, uint256 acceptedWeight);
    error InvalidGuardianStatus(
        GuardianStatus guardianStatus, GuardianStatus expectedGuardianStatus
    );
    error InvalidAccountAddress();
    error NoRecoveryConfigured();
    error NotEnoughApprovals(uint256 currentWeight, uint256 threshold);
    error DelayNotPassed(uint256 blockTimestamp, uint256 executeAfter);
    error RecoveryRequestExpired(uint256 blockTimestamp, uint256 executeBefore);
    error InvalidRecoveryDataHash(bytes32 recoveryDataHash, bytes32 expectedRecoveryDataHash);
    error NoRecoveryInProcess();
    error NotCancelUnexpiredRequest(address account, uint256 blockTimestamp, uint256 executeBefore);
    error RecoveryIsNotActivated();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          FUNCTIONS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getRecoveryConfig(address account) external view returns (RecoveryConfig memory);

    function getRecoveryRequest(address account) external view returns (RecoveryRequest memory);

    function updateRecoveryConfig(RecoveryConfig calldata recoveryConfig) external;

    function cancelRecovery() external;
}
