// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC7579ExecutorBase} from "@rhinestone/modulekit/src/Modules.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {IRecoveryModule} from "./interfaces/IRecoveryModule.sol";
import {IGuardian} from "./interfaces/IGuardian.sol";

contract RecoveryModule is ERC7579ExecutorBase, IRecoveryModule {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    uint256 public constant MINIMUM_RECOVERY_WINDOW = 2 days;
    struct RecoveryConfig {
        EnumerableSet.AddressSet guardians;
        uint256 threshold;
        uint256 delay;
        uint256 expiry;
    }
    struct RecoveryRequest {
        uint256 executeAfter;
        uint256 executeBefore;
        uint256 approvals;
        bytes32 recoveryDataHash;
        mapping(address guardian => bool approved) guardianApproved;
    }

    mapping(address account => mapping(address validator => RecoveryConfig recoveryConfig))
        internal recoveryConfigs;

    mapping(address account => mapping(address validator => RecoveryRequest recoveryRequest))
        internal recoveryRequests;

    modifier onlyWhenNotRecovering(address account, address validator) {
        uint256 approvals = recoveryRequests[account][validator].approvals;
        if (approvals > 0) {
            revert RecoveryInProcess();
        }
        _;
    }

    /**
     * @dev This function is called by the smart account during installation of the validator
     * @param data arbitrary data that may be required on the validator during `onInstall`
     * initialization
     *
     * MUST revert on error (i.e. if validator is already enabled)
     */
    function onInstall(bytes calldata data) external {
        (
            address validator,
            address[] memory guardians,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (address, address[], uint256, uint256, uint256));
        address account = msg.sender;
        uint256 guardianCount = guardians.length;
        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }
        RecoveryConfig storage recoveryConfig = recoveryConfigs[account][
            validator
        ];
        for (uint256 i = 0; i < guardianCount; i++) {
            address guardian = guardians[i];
            if (guardian == address(0) || guardian == account) {
                revert InvalidGuardianAddress(guardian);
            }
            recoveryConfig.guardians.add(guardian);
        }
        if (threshold > guardianCount) {
            revert ThresholdExceedsGuardianCount(threshold, guardianCount);
        }
        if (delay > expiry) {
            revert DelayMoreThanExpiry(delay, expiry);
        }
        uint256 recoveryWindow = expiry - delay;
        if (recoveryWindow < MINIMUM_RECOVERY_WINDOW) {
            revert RecoveryWindowTooShort(recoveryWindow);
        }

        recoveryConfig.threshold = threshold;
        recoveryConfig.delay = delay;
        recoveryConfig.expiry = expiry;

        emit RecoveryConfigured(
            account,
            validator,
            guardianCount,
            threshold,
            delay,
            expiry
        );
    }

    /**
     * @dev This function is called by the smart account during uninstallation of the validator
     * @param data arbitrary data that may be required on the validator during `onUninstall`
     * de-initialization
     *
     * MUST revert on error
     */
    function onUninstall(bytes calldata data) external {
        // TODO: implement (merge-ok)
    }

    /**
     * @dev Returns boolean value if validator is a certain type
     * @param moduleTypeId the validator type ID according the ERC-7579 spec
     *
     * MUST return true if the validator is of the given type and false otherwise
     */
    function isModuleType(uint256 moduleTypeId) external pure returns (bool) {
        return moduleTypeId == TYPE_EXECUTOR;
    }

    /**
     * @dev Returns if the validator was already initialized for a provided smartaccount
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        // TODO: implement (merge-ok)
        return false;
    }

    /**
     * @notice Retrieves the recovery configuration for a given account and validator
     * @param account The account
     * @param validator The validator to recover
     */
    function getRecoveryConfig(
        address account,
        address validator
    ) external view returns (address[] memory, uint256, uint256, uint256) {
        RecoveryConfig storage recoveryConfig = recoveryConfigs[account][
            validator
        ];

        address[] memory guardians;
        for (uint256 i = 0; i < recoveryConfig.guardians.length(); i++) {
            guardians[i] = recoveryConfig.guardians.at(i);
        }

        return (
            guardians,
            recoveryConfig.threshold,
            recoveryConfig.delay,
            recoveryConfig.expiry
        );
    }

    /**
     * @notice Retrieves the recovery request details for a given account and validator
     * @dev Does not return guardianVoted as that is part of a nested mapping
     * @param account The address of the account for which the recovery request details are being
     * retrieved
     */
    function getRecoveryRequest(
        address account,
        address validator
    ) external view returns (uint256, uint256, uint256, bytes32) {
        RecoveryRequest storage recoveryRequest = recoveryRequests[account][
            validator
        ];

        return (
            recoveryRequest.executeAfter,
            recoveryRequest.executeBefore,
            recoveryRequest.approvals,
            recoveryRequest.recoveryDataHash
        );
    }

    /**
     * @notice Initiates a recovery for a given account
     * @dev called once per guardian
     * @param account The account
     * @param validator The validator to recover
     * @param signature Signature/proof of guardian authentication
     * @param hash The recovery calldata hash
     */
    function approveRecovery(
        address account,
        address validator,
        address guardian,
        bytes memory signature,
        bytes32 hash
    ) external {
        uint256 threshold = recoveryConfigs[account][validator].threshold;

        RecoveryRequest storage recoveryRequest = recoveryRequests[account][
            validator
        ];

        if (threshold == 0) {
            revert NoRecoveryConfigured();
        }

        if (recoveryRequest.guardianApproved[guardian]) {
            revert GuardianAlreadyVoted();
        }

        bool isVerified = IGuardian(guardian).verifySignature(signature, hash);
        if (!isVerified) {
            revert InvalidGuardianSignature();
        }

        // If recoveryDataHash is 0, this is the first guardian and the request is initialized
        if (recoveryRequest.recoveryDataHash == bytes32(0)) {
            recoveryRequest.recoveryDataHash = hash;

            uint256 executeBefore = block.timestamp +
                recoveryConfigs[account][validator].expiry;
            recoveryRequest.executeBefore = executeBefore;
            emit RecoveryRequestStarted(
                account,
                validator,
                executeBefore,
                hash
            );
        }

        if (recoveryRequest.recoveryDataHash != hash) {
            revert InvalidRecoveryDataHash(
                hash,
                recoveryRequest.recoveryDataHash
            );
        }

        recoveryRequest.approvals += 1;
        recoveryRequest.guardianApproved[guardian] = true;
        emit GuardianVoted(
            account,
            validator,
            guardian,
            recoveryRequest.approvals
        );

        if (recoveryRequest.approvals >= threshold) {
            uint256 executeAfter = block.timestamp +
                recoveryConfigs[account][validator].delay;
            recoveryRequest.executeAfter = executeAfter;

            emit RecoveryRequestComplete(
                account,
                validator,
                executeAfter,
                recoveryRequest.executeBefore,
                hash
            );
        }
    }

    /**
     * @notice Completes the recovery flow for a given account
     * @param account The account to recovery
     * @param recoveryCalldata Data needed to finalize the recovery
     */
    function executeRecovery(
        address account,
        address validator,
        bytes calldata recoveryCalldata
    ) external {
        if (account == address(0)) {
            revert InvalidAccountAddress();
        }
        RecoveryRequest storage recoveryRequest = recoveryRequests[account][
            validator
        ];

        uint256 threshold = recoveryConfigs[account][validator].threshold;
        if (threshold == 0) {
            revert NoRecoveryConfigured();
        }

        if (recoveryRequest.approvals < threshold) {
            revert NotEnoughApprovals(recoveryRequest.approvals, threshold);
        }

        if (block.timestamp < recoveryRequest.executeAfter) {
            revert DelayNotPassed(
                block.timestamp,
                recoveryRequest.executeAfter
            );
        }

        if (block.timestamp >= recoveryRequest.executeBefore) {
            revert RecoveryRequestExpired(
                block.timestamp,
                recoveryRequest.executeBefore
            );
        }

        bytes32 recoveryDataHash = keccak256(recoveryCalldata);
        if (recoveryDataHash != recoveryRequest.recoveryDataHash) {
            revert InvalidRecoveryDataHash(
                recoveryDataHash,
                recoveryRequest.recoveryDataHash
            );
        }

        // TODO: clear recovery request (merge-ok)

        _execute({
            account: account,
            to: validator,
            value: 0,
            data: recoveryCalldata
        });

        emit RecoveryExecuted(account, validator);
    }

    /**
     * @notice Cancels an ongoing recovery request for a given account
     * @param account The account
     * @param validator The validator to recover
     */
    function cancelRecovery(address account, address validator) external {
        // TODO: implement (merge-ok)
    }
}
