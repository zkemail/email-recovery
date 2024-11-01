// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
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
        uint256 delay; // the time from when the threshold for a recovery request has passed (when
            // the attempt is successful), until the recovery request can be executed. The delay can
            // be used to give the account owner time to react in case a malicious recovery
            // attempt is started by a guardian
        uint256 expiry; // the time from when a recovery request is started until the recovery
            // request becomes invalid. The recovery expiry encourages the timely execution of
            // successful recovery attempts, and reduces the risk of unauthorized access through
            // stale or outdated requests. After the recovery expiry has passed, anyone can cancel
            // the recovery request
    }

    struct PreviousRecoveryRequest {
        address previousGuardianInitiated; // the address of the guardian who initiated the previous
            // recovery request. Used to prevent a malicious guardian threatening the liveness of
            // the recovery attempt. For example, a guardian could initiate a recovery request with
            // a recovery data hash for calldata that recovers the account to their own
            // private key. Recording the previous guardian to initiate the request can be used
            // in combination with a cooldown to stop the guardian blocking recovery with an
            // invalid hash which is replaced by another invalid recovery hash after the request
            // is cancelled
        uint256 cancelRecoveryCooldown; // Used in conjunction with previousGuardianInitiated to
            // stop a guardian blocking subsequent recovery requests with an invalid hash each time.
            // Other guardians can react in time before the cooldown expires to start a valid
            // recovery request with a valid hash
    }

    /**
     * A struct representing the values required for a recovery request.
     * The request state should be maintained over a single recovery attempt unless
     * explicitly modified. It should be deleted after a recovery attempt has been processed
     */
    struct RecoveryRequest {
        uint256 executeAfter; // the timestamp from which the recovery request can be executed
        uint256 executeBefore; // the timestamp from which the recovery request becomes invalid
        uint256 currentWeight; // total weight of all guardian approvals for the recovery request
        bytes32 recoveryDataHash; // the keccak256 hash of the recovery data used to execute the
            // recovery attempt
        EnumerableSet.AddressSet guardianVoted; // the set of guardians who have voted for the
            // recovery request. Must be looped through manually to delete each value
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    event RecoveryConfigured(
        address indexed account, uint256 guardianCount, uint256 totalWeight, uint256 threshold
    );
    event RecoveryConfigUpdated(address indexed account, uint256 delay, uint256 expiry);
    event GuardianAccepted(address indexed account, address indexed guardian);
    event RecoveryRequestStarted(
        address indexed account,
        address indexed guardian,
        uint256 executeBefore,
        bytes32 recoveryDataHash
    );
    event GuardianVoted(
        address indexed account,
        address indexed guardian,
        uint256 currentWeight,
        uint256 guardianWeight
    );
    event RecoveryRequestComplete(
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

    error KillSwitchEnabled();
    error InvalidVerifier();
    error InvalidDkimRegistry();
    error InvalidEmailAuthImpl();
    error InvalidCommandHandler();
    error InvalidKillSwitchAuthorizer();
    error InvalidFactory();
    error InvalidProxyBytecodeHash();
    error SetupAlreadyCalled();
    error AccountNotConfigured();
    error DelayLessThanMinimumDelay(uint256 delay, uint256 minimumDelay);
    error DelayMoreThanExpiry(uint256 delay, uint256 expiry);
    error RecoveryWindowTooShort(uint256 recoveryWindow);
    error ThresholdExceedsAcceptedWeight(uint256 threshold, uint256 acceptedWeight);
    error InvalidGuardianStatus(
        GuardianStatus guardianStatus, GuardianStatus expectedGuardianStatus
    );
    error GuardianAlreadyVoted();
    error GuardianMustWaitForCooldown(address guardian);
    error InvalidAccountAddress();
    error NoRecoveryConfigured();
    error NotEnoughApprovals(uint256 currentWeight, uint256 threshold);
    error DelayNotPassed(uint256 blockTimestamp, uint256 executeAfter);
    error RecoveryRequestExpired(uint256 blockTimestamp, uint256 executeBefore);
    error InvalidRecoveryDataHash(bytes32 recoveryDataHash, bytes32 expectedRecoveryDataHash);
    error NoRecoveryInProcess();
    error RecoveryHasNotExpired(address account, uint256 blockTimestamp, uint256 executeBefore);
    error RecoveryIsNotActivated();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          FUNCTIONS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getRecoveryConfig(address account) external view returns (RecoveryConfig memory);

    function getRecoveryRequest(address account)
        external
        view
        returns (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        );

    function updateRecoveryConfig(RecoveryConfig calldata recoveryConfig) external;

    function getPreviousRecoveryRequest(address account)
        external
        view
        returns (PreviousRecoveryRequest memory);

    function hasGuardianVoted(address account, address guardian) external view returns (bool);

    function cancelRecovery() external;

    function cancelExpiredRecovery(address account) external;

    function toggleKillSwitch() external;
}
