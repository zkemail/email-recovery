// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { GuardianStorage, GuardianStatus } from "../libraries/EnumerableGuardianMap.sol";

interface IEmailRecoveryManager {
    /*//////////////////////////////////////////////////////////////////////////
                                TYPE DELARATIONS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * A struct representing the values required for recovery configuration
     * Config should be maintained over subsequent recovery attempts unless explicitly modified
     */
    struct RecoveryConfig {
        address recoveryModule; // the trusted recovery module that has permission to recover an
            // account
        uint256 delay; // the time from when recovery is started until the recovery request can be
            // executed
        uint256 expiry; // the time from when recovery is started until the recovery request becomes
            // invalid.
            // The recovery expiry encourages the timely execution of successful recovery attempts,
            // and reduces
            // the risk of unauthorized access through stale or outdated requests.
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
        bytes32 calldataHash; // the keccak256 hash of the calldata used to execute the recovery
            // attempt
    }

    /**
     * A struct representing the values required for guardian configuration
     * Config should be maintained over subsequent recovery attempts unless explicitly modified
     */
    struct GuardianConfig {
        uint256 guardianCount;
        uint256 totalWeight;
        uint256 threshold;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    EVENTS
    //////////////////////////////////////////////////////////////////////////*/

    event RecoveryConfigured(
        address indexed account, address indexed recoveryModule, uint256 guardianCount
    );
    event RecoveryConfigUpdated(
        address indexed account, address indexed recoveryModule, uint256 delay, uint256 expiry
    );
    event GuardianAccepted(address indexed account, address indexed guardian);
    event RecoveryDeInitialized(address indexed account);
    event RecoveryProcessed(address indexed account, uint256 executeAfter, uint256 executeBefore);
    event RecoveryCompleted(address indexed account);
    event RecoveryCancelled(address indexed account);

    /**
     * Guardian logic events
     */
    event AddedGuardian(address indexed account, address indexed guardian);
    event RemovedGuardian(address indexed account, address indexed guardian);
    event ChangedThreshold(address indexed account, uint256 threshold);

    /*//////////////////////////////////////////////////////////////////////////
                                    ERRORS
    //////////////////////////////////////////////////////////////////////////*/

    error AccountNotConfigured();
    error NotRecoveryModule();
    error SetupAlreadyCalled();
    error RecoveryInProcess();
    error InvalidTemplateIndex();
    error InvalidSubjectParams();
    error InvalidGuardianStatus(
        GuardianStatus guardianStatus, GuardianStatus expectedGuardianStatus
    );
    error InvalidNewOwner();
    error InvalidRecoveryModule();
    error RecoveryModuleNotInstalled();
    error NotEnoughApprovals();
    error DelayNotPassed();
    error RecoveryRequestExpired();
    error DelayMoreThanExpiry();
    error RecoveryWindowTooShort();
    error InvalidCalldataHash();
    error InvalidAccountAddress();

    /**
     * Email Auth access control errors
     */
    error UnauthorizedAccountForGuardian();

    /*//////////////////////////////////////////////////////////////////////////
                                    FUNCTIONS
    //////////////////////////////////////////////////////////////////////////*/

    function getRecoveryRequest(address account) external view returns (RecoveryRequest memory);

    function getRecoveryConfig(address account) external view returns (RecoveryConfig memory);

    function configureRecovery(
        address recoveryModule,
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    )
        external;

    function deInitRecoveryFromModule(address account) external;

    function cancelRecovery() external;

    function updateRecoveryConfig(RecoveryConfig calldata recoveryConfig) external;

    /*//////////////////////////////////////////////////////////////////////////
                                GUARDIAN LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function getGuardianConfig(address account) external view returns (GuardianConfig memory);

    function getGuardian(
        address account,
        address guardian
    )
        external
        view
        returns (GuardianStorage memory);

    function addGuardian(address guardian, uint256 weight, uint256 threshold) external;

    function removeGuardian(address guardian, uint256 threshold) external;

    function changeThreshold(uint256 threshold) external;

    /*//////////////////////////////////////////////////////////////////////////
                                EMAIL AUTH LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function updateGuardianDKIMRegistry(address guardian, address dkimRegistryAddr) external;

    function updateGuardianVerifier(address guardian, address verifierAddr) external;

    function upgradeEmailAuthGuardian(
        address guardian,
        address newImplementation,
        bytes memory data
    )
        external;
}
