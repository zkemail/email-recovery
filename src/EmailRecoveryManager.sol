// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAccountRecovery } from
    "@zk-email/ether-email-auth-contracts/src/EmailAccountRecovery.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IEmailRecoveryManager } from "./interfaces/IEmailRecoveryManager.sol";
import { IEmailRecoveryCommandHandler } from "./interfaces/IEmailRecoveryCommandHandler.sol";
import { GuardianManager } from "./GuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "./libraries/EnumerableGuardianMap.sol";

/**
 * @title EmailRecoveryManager
 * @notice Provides a mechanism for account recovery using email guardians
 * @dev The underlying EmailAccountRecovery contract provides some base logic for deploying
 * guardian contracts and handling email verification.
 *
 * This contract defines an implementation for email-based recovery. It is designed to
 * provide the core logic for email-based account recovery that can be used across different
 * account implementations. The core logic is agnostic to the account implementation and could be
 * implemented as part of a smart account module, or on a smart account itself.
 *
 * EmailRecoveryManager defines "what a valid recovery attempt is for an account", and leaves
 * defining "how that recovery attempt is executed on the account" to contracts implementing
 * EmailRecoveryManager. A specific email command handler is also accociated with a recovery
 * manager. A command handler defines and validates the recovery email commands. Developers can
 * write their own command handlers to make specifc commands
 */
abstract contract EmailRecoveryManager is
    EmailAccountRecovery,
    GuardianManager,
    Ownable,
    IEmailRecoveryManager
{
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * Minimum required time window between when a recovery attempt becomes valid and when it
     * becomes invalid
     */
    uint256 public constant MINIMUM_RECOVERY_WINDOW = 2 days;

    /**
     * The cooldown period after which a subsequent recovery attempt can be initiated by the same
     * guardian
     */
    uint256 public constant CANCEL_EXPIRED_RECOVERY_COOLDOWN = 1 days;

    /**
     * The command handler that returns and validates the command templates
     */
    address public immutable commandHandler;

    /**
     * boolean flag for the kill switch being enabled or disabled
     */
    bool public killSwitchEnabled;

    /**
     * The minimum delay before a successful recovery attempt can be executed
     */
    uint256 public immutable minimumDelay;

    /**
     * Account address to recovery config
     */
    mapping(address account => RecoveryConfig recoveryConfig) internal recoveryConfigs;

    /**
     * Account address to recovery request
     */
    mapping(address account => RecoveryRequest recoveryRequest) internal recoveryRequests;

    /**
     * Account address to previous recovery request
     */
    mapping(address account => PreviousRecoveryRequest previousRecoveryRequest) internal
        previousRecoveryRequests;

    modifier onlyWhenActive() {
        if (killSwitchEnabled) {
            revert KillSwitchEnabled();
        }
        _;
    }

    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl,
        address _commandHandler,
        uint256 _minimumDelay,
        address _killSwitchAuthorizer
    )
        Ownable(_killSwitchAuthorizer)
    {
        if (_verifier == address(0)) {
            revert InvalidVerifier();
        }
        if (_dkimRegistry == address(0)) {
            revert InvalidDkimRegistry();
        }
        if (_emailAuthImpl == address(0)) {
            revert InvalidEmailAuthImpl();
        }
        if (_commandHandler == address(0)) {
            revert InvalidCommandHandler();
        }
        if (_killSwitchAuthorizer == address(0)) {
            revert InvalidKillSwitchAuthorizer();
        }
        verifierAddr = _verifier;
        dkimAddr = _dkimRegistry;
        emailAuthImplementationAddr = _emailAuthImpl;
        commandHandler = _commandHandler;
        minimumDelay = _minimumDelay;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*       RECOVERY CONFIG, REQUEST AND TEMPLATE GETTERS        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves the recovery configuration for a given account
     * @param account The address of the account for which the recovery configuration is being
     * retrieved
     * @return RecoveryConfig The recovery configuration for the specified account
     */
    function getRecoveryConfig(address account) external view returns (RecoveryConfig memory) {
        return recoveryConfigs[account];
    }

    /**
     * @notice Retrieves the recovery request details for a given account
     * @dev Does not return guardianVoted as that is part of a nested mapping
     * @param account The address of the account for which the recovery request details are being
     * retrieved
     * @return executeAfter The timestamp from which the recovery request can be executed
     * @return executeBefore The timestamp from which the recovery request becomes invalid
     * @return currentWeight Total weight of all guardian approvals for the recovery request
     * @return recoveryDataHash The keccak256 hash of the recovery data used to execute the recovery
     * attempt
     */
    function getRecoveryRequest(address account)
        external
        view
        returns (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        )
    {
        return (
            recoveryRequests[account].executeAfter,
            recoveryRequests[account].executeBefore,
            recoveryRequests[account].currentWeight,
            recoveryRequests[account].recoveryDataHash
        );
    }

    /**
     * @notice Retrieves the previous recovery request details for a given account
     * @dev the previous recovery request is stored as this helps prevent guardians threatening the
     * liveness of recovery attempts by submitting malicious recovery hashes before honest guardians
     * correctly submit theirs. See `processRecovery` and `cancelExpiredRecovery` for more details
     * @param account The address of the account for which the previous recovery request details are
     * being retrieved
     * @return PreviousRecoveryRequest The previous recovery request for the specified account
     */
    function getPreviousRecoveryRequest(address account)
        external
        view
        returns (PreviousRecoveryRequest memory)
    {
        return previousRecoveryRequests[account];
    }

    /**
     * @notice Returns whether a guardian has voted on the current recovery request for a given
     * account
     * @param account The address of the account for which the recovery request is being checked
     * @param guardian The address of the guardian to check voted status
     * @return bool The boolean value indicating whether the guardian has voted on the recovery
     * request
     */
    function hasGuardianVoted(address account, address guardian) public view returns (bool) {
        return recoveryRequests[account].guardianVoted.contains(guardian);
    }

    /**
     * @notice Checks if the recovery is activated for a given account
     * @param account The address of the account for which the activation status is being checked
     * @return bool True if the recovery request is activated, false otherwise
     */
    function isActivated(address account) public view override returns (bool) {
        return guardianConfigs[account].threshold > 0;
    }

    /**
     * @notice Returns a two-dimensional array of strings representing the command templates for an
     * acceptance by a new guardian.
     * @dev This is retrieved from the associated command handler. Developers can write their own
     * command handlers, this is useful for account implementations which require different data in
     * the command or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function acceptanceCommandTemplates() public view override returns (string[][] memory) {
        return IEmailRecoveryCommandHandler(commandHandler).acceptanceCommandTemplates();
    }

    /**
     * @notice Returns a two-dimensional array of strings representing the command templates for
     * email recovery.
     * @dev This is retrieved from the associated command handler. Developers can write their own
     * command handlers, this is useful for account implementations which require different data in
     * the command or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function recoveryCommandTemplates() public view override returns (string[][] memory) {
        return IEmailRecoveryCommandHandler(commandHandler).recoveryCommandTemplates();
    }

    /**
     * @notice Extracts the account address to be recovered from the command parameters of an
     * acceptance email.
     * @dev This is retrieved from the associated command handler.
     * @param commandParams The command parameters of the acceptance email.
     * @param templateIdx The index of the acceptance command template.
     */
    function extractRecoveredAccountFromAcceptanceCommand(
        bytes[] memory commandParams,
        uint256 templateIdx
    )
        public
        view
        override
        returns (address)
    {
        return IEmailRecoveryCommandHandler(commandHandler)
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);
    }

    /**
     * @notice Extracts the account address to be recovered from the command parameters of a
     * recovery email.
     * @dev This is retrieved from the associated command handler.
     * @param commandParams The command parameters of the recovery email.
     * @param templateIdx The index of the recovery command template.
     */
    function extractRecoveredAccountFromRecoveryCommand(
        bytes[] memory commandParams,
        uint256 templateIdx
    )
        public
        view
        override
        returns (address)
    {
        return IEmailRecoveryCommandHandler(commandHandler)
            .extractRecoveredAccountFromRecoveryCommand(commandParams, templateIdx);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     CONFIGURE RECOVERY                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Configures recovery for the caller's account. This is the first core function
     * that must be called during the end-to-end recovery flow
     * @dev Can only be called once for configuration. Sets up the guardians, and validates config
     * parameters, ensuring that no recovery is in process. It is possible to update configuration
     * at a later stage if neccessary
     * @param guardians An array of guardian addresses
     * @param weights An array of weights corresponding to each guardian
     * @param threshold The threshold weight required for recovery
     * @param delay The delay period before recovery can be executed
     * @param expiry The expiry time after which the recovery attempt is invalid
     */
    function configureRecovery(
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    )
        internal
        onlyWhenActive
    {
        address account = msg.sender;

        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        if (guardianConfigs[account].threshold > 0) {
            revert SetupAlreadyCalled();
        }

        (uint256 guardianCount, uint256 totalWeight) =
            setupGuardians(account, guardians, weights, threshold);

        RecoveryConfig memory recoveryConfig = RecoveryConfig(delay, expiry);
        updateRecoveryConfig(recoveryConfig);

        emit RecoveryConfigured(account, guardianCount, totalWeight, threshold);
    }

    /**
     * @notice Updates and validates the recovery configuration for the caller's account
     * @dev Validates and sets the new recovery configuration for the caller's account, ensuring
     * that no recovery is in process.
     * @param recoveryConfig The new recovery configuration to be set for the caller's account
     */
    function updateRecoveryConfig(RecoveryConfig memory recoveryConfig)
        public
        onlyWhenNotRecovering
        onlyWhenActive
    {
        address account = msg.sender;

        if (guardianConfigs[account].threshold == 0) {
            revert AccountNotConfigured();
        }
        if (recoveryConfig.delay < minimumDelay) {
            revert DelayLessThanMinimumDelay(recoveryConfig.delay, minimumDelay);
        }
        if (recoveryConfig.delay > recoveryConfig.expiry) {
            revert DelayMoreThanExpiry(recoveryConfig.delay, recoveryConfig.expiry);
        }
        uint256 recoveryWindow = recoveryConfig.expiry - recoveryConfig.delay;
        if (recoveryWindow < MINIMUM_RECOVERY_WINDOW) {
            revert RecoveryWindowTooShort(recoveryWindow);
        }

        recoveryConfigs[account] = recoveryConfig;

        emit RecoveryConfigUpdated(account, recoveryConfig.delay, recoveryConfig.expiry);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HANDLE ACCEPTANCE                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Accepts a guardian for the specified account. This is the second core function
     * that must be called during the end-to-end recovery flow
     * @dev Called once per guardian added. Although this adds an extra step to recovery, this
     * acceptance flow is an important security feature to ensure that no typos are made when adding
     * a guardian, and that the guardian is in control of the specified email address. Called as
     * part of handleAcceptance in EmailAccountRecovery
     * @param guardian The address of the guardian to be accepted
     * @param templateIdx The index of the template used for acceptance
     * @param commandParams An array of bytes containing the command parameters
     * @param {nullifier} Unused parameter. The nullifier acts as a unique identifier for an email,
     * but it is not required in this implementation
     */
    function acceptGuardian(
        address guardian,
        uint256 templateIdx,
        bytes[] memory commandParams,
        bytes32 /* nullifier */
    )
        internal
        override
        onlyWhenActive
    {
        address account = IEmailRecoveryCommandHandler(commandHandler).validateAcceptanceCommand(
            templateIdx, commandParams
        );

        if (recoveryRequests[account].currentWeight > 0) {
            revert RecoveryInProcess();
        }

        if (!isActivated(account)) {
            revert RecoveryIsNotActivated();
        }

        // This check ensures GuardianStatus is correct and also implicitly that the
        // account in the email is a valid account
        GuardianStorage memory guardianStorage = getGuardian(account, guardian);
        if (guardianStorage.status != GuardianStatus.REQUESTED) {
            revert InvalidGuardianStatus(guardianStorage.status, GuardianStatus.REQUESTED);
        }

        updateGuardianStatus(account, guardian, GuardianStatus.ACCEPTED);
        guardianConfigs[account].acceptedWeight += guardianStorage.weight;

        emit GuardianAccepted(account, guardian);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      HANDLE RECOVERY                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Processes a recovery request for a given account. This is the third core function
     * that must be called during the end-to-end recovery flow
     * @dev Called once per guardian until the threshold is reached
     * @param guardian The address of the guardian initiating/voting on the recovery request
     * @param templateIdx The index of the template used for the recovery request
     * @param commandParams An array of bytes containing the command parameters
     * @param {nullifier} Unused parameter. The nullifier acts as a unique identifier for an email,
     * but it is not required in this implementation
     */
    function processRecovery(
        address guardian,
        uint256 templateIdx,
        bytes[] memory commandParams,
        bytes32 /* nullifier */
    )
        internal
        override
        onlyWhenActive
    {
        address account = IEmailRecoveryCommandHandler(commandHandler).validateRecoveryCommand(
            templateIdx, commandParams
        );

        if (!isActivated(account)) {
            revert RecoveryIsNotActivated();
        }

        GuardianConfig memory guardianConfig = guardianConfigs[account];
        if (guardianConfig.threshold > guardianConfig.acceptedWeight) {
            revert ThresholdExceedsAcceptedWeight(
                guardianConfig.threshold, guardianConfig.acceptedWeight
            );
        }

        // This check ensures GuardianStatus is correct and also implicitly that the
        // account in the email is a valid account
        GuardianStorage memory guardianStorage = getGuardian(account, guardian);
        if (guardianStorage.status != GuardianStatus.ACCEPTED) {
            revert InvalidGuardianStatus(guardianStorage.status, GuardianStatus.ACCEPTED);
        }

        RecoveryRequest storage recoveryRequest = recoveryRequests[account];
        bytes32 recoveryDataHash = IEmailRecoveryCommandHandler(commandHandler)
            .parseRecoveryDataHash(templateIdx, commandParams);

        if (hasGuardianVoted(account, guardian)) {
            revert GuardianAlreadyVoted();
        }

        // A malicious guardian can submit an invalid recovery hash that the
        // other guardians do not agree with, and also re-submit the same invalid hash once
        // the expired recovery attempt has been cancelled, thereby threatening the
        // liveness of the recovery attempt. Adding a cooldown period in this scenario gives other
        // guardians time to react before the malicious guardian adds another recovery hash
        uint256 guardianCount = guardianConfigs[account].guardianCount;
        bool cooldownNotExpired =
            previousRecoveryRequests[account].cancelRecoveryCooldown > block.timestamp;
        if (
            previousRecoveryRequests[account].previousGuardianInitiated == guardian
                && cooldownNotExpired && guardianCount > 1
        ) {
            revert GuardianMustWaitForCooldown(guardian);
        }

        // If recoveryDataHash is 0, this is the first guardian and the request is initialized
        if (recoveryRequest.recoveryDataHash == bytes32(0)) {
            recoveryRequest.recoveryDataHash = recoveryDataHash;
            previousRecoveryRequests[account].previousGuardianInitiated = guardian;
            uint256 executeBefore = block.timestamp + recoveryConfigs[account].expiry;
            recoveryRequest.executeBefore = executeBefore;
            emit RecoveryRequestStarted(account, guardian, executeBefore, recoveryDataHash);
        }

        if (recoveryRequest.recoveryDataHash != recoveryDataHash) {
            revert InvalidRecoveryDataHash(recoveryDataHash, recoveryRequest.recoveryDataHash);
        }

        recoveryRequest.currentWeight += guardianStorage.weight;
        recoveryRequest.guardianVoted.add(guardian);
        emit GuardianVoted(account, guardian, recoveryRequest.currentWeight, guardianStorage.weight);
        if (recoveryRequest.currentWeight >= guardianConfig.threshold) {
            uint256 executeAfter = block.timestamp + recoveryConfigs[account].delay;
            recoveryRequest.executeAfter = executeAfter;

            emit RecoveryRequestComplete(
                account, guardian, executeAfter, recoveryRequest.executeBefore, recoveryDataHash
            );
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     COMPLETE RECOVERY                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Completes the recovery process for a given account. This is the forth and final
     * core function that must be called during the end-to-end recovery flow. Can be called by
     * anyone.
     * @dev Validates the recovery request by checking the total weight, that the delay has passed,
     * and the request has not expired. Calls the virtual `recover()` function which triggers
     * recovery. This function deletes the recovery request but recovery config state is maintained
     * so future recovery requests can be made without having to reconfigure everything
     * @param account The address of the account for which the recovery is being completed
     * @param recoveryData The data that is passed to recover the validator or account.
     * recoveryData = abi.encode(validatorOrAccount, recoveryFunctionCalldata). Although, it is
     * possible to design an account/module using this manager without encoding the validator or
     * account, depending on how the `handler.parseRecoveryDataHash()` and `recover()` functions
     * are implemented
     */
    function completeRecovery(
        address account,
        bytes calldata recoveryData
    )
        external
        override
        onlyWhenActive
    {
        if (account == address(0)) {
            revert InvalidAccountAddress();
        }
        RecoveryRequest storage recoveryRequest = recoveryRequests[account];

        uint256 threshold = guardianConfigs[account].threshold;
        if (threshold == 0) {
            revert NoRecoveryConfigured();
        }

        if (recoveryRequest.currentWeight < threshold) {
            revert NotEnoughApprovals(recoveryRequest.currentWeight, threshold);
        }

        if (block.timestamp < recoveryRequest.executeAfter) {
            revert DelayNotPassed(block.timestamp, recoveryRequest.executeAfter);
        }

        if (block.timestamp >= recoveryRequest.executeBefore) {
            revert RecoveryRequestExpired(block.timestamp, recoveryRequest.executeBefore);
        }

        bytes32 recoveryDataHash = keccak256(recoveryData);
        if (recoveryDataHash != recoveryRequest.recoveryDataHash) {
            revert InvalidRecoveryDataHash(recoveryDataHash, recoveryRequest.recoveryDataHash);
        }

        clearRecoveryRequest(account);

        recover(account, recoveryData);

        emit RecoveryCompleted(account);
    }

    /**
     * @notice Called during completeRecovery to finalize recovery. Contains implementation-specific
     * logic to recover an account
     * @dev this is the only function that must be implemented by consuming contracts to use the
     * email recovery manager. This does not encompass other important logic such as module
     * installation, that logic is specific to each implementation and must be implemeted separately
     * @param account The address of the account for which the recovery is being completed
     * @param recoveryData The data that is passed to recover the validator or account.
     * recoveryData = abi.encode(validatorOrAccount, recoveryFunctionCalldata). Although, it is
     * possible to design an account/module using this manager without encoding the validator or
     * account, depending on how the `handler.parseRecoveryDataHash()` and `recover()` functions
     * are implemented
     */
    function recover(address account, bytes calldata recoveryData) internal virtual;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CANCEL/DE-INIT LOGIC                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Cancels the recovery request for the caller's account
     * @dev Deletes the current recovery request associated with the caller's account
     */
    function cancelRecovery() external onlyWhenActive {
        if (recoveryRequests[msg.sender].currentWeight == 0) {
            revert NoRecoveryInProcess();
        }
        clearRecoveryRequest(msg.sender);
        emit RecoveryCancelled(msg.sender);
    }

    /**
     * @notice Cancels the recovery request for a given account if it is expired.
     * @dev Deletes the current recovery request associated with the given account if the recovery
     * request has expired.
     * @param account The address of the account for which the recovery is being cancelled
     */
    function cancelExpiredRecovery(address account) external onlyWhenActive {
        if (recoveryRequests[account].currentWeight == 0) {
            revert NoRecoveryInProcess();
        }
        if (recoveryRequests[account].executeBefore > block.timestamp) {
            revert RecoveryHasNotExpired(
                account, block.timestamp, recoveryRequests[account].executeBefore
            );
        }
        previousRecoveryRequests[account].cancelRecoveryCooldown =
            block.timestamp + CANCEL_EXPIRED_RECOVERY_COOLDOWN;
        clearRecoveryRequest(account);
        emit RecoveryCancelled(account);
    }

    /**
     * @notice Removes all state related to msg.sender.
     * @dev A feature specifically important for smart account modules - in order to prevent
     * unexpected behaviour when reinstalling account modules, the contract state should be
     * deinitialized. This should include removing state accociated with an account.
     */
    function deInitRecoveryModule() internal onlyWhenNotRecovering {
        address account = msg.sender;
        deInitRecoveryModule(account);
    }

    /**
     * @notice Removes all state related to an account.
     * @dev Although this function is internal, it should be used carefully as it can be called by
     * anyone. A feature specifically important for smart account modules - in order to prevent
     * unexpected behaviour when reinstalling account modules, the contract state should be
     * deinitialized. This should include removing state accociated with an account
     * @param account The address of the account for which recovery is being deinitialized
     */
    function deInitRecoveryModule(address account) internal onlyWhenNotRecovering {
        delete recoveryConfigs[account];
        clearRecoveryRequest(account);
        delete previousRecoveryRequests[account];

        removeAllGuardians(account);
        delete guardianConfigs[account];

        emit RecoveryDeInitialized(account);
    }

    /**
     * @notice Clears the recovery request for an account
     * @dev Because `guardianVoted` on the `RecoveryRequest` struct is an `EnumerableSet`, we need
     * to manually clear all entries. The maximum guardian count is 32, which is enforced by
     * `EnumerableGuardianMap.sol`. Therefore no more than 32 values should have to be removed from
     * the set
     * @param account The address of the account for which the recovery request is being cleared
     */
    function clearRecoveryRequest(address account) internal {
        RecoveryRequest storage recoveryRequest = recoveryRequests[account];

        address[] memory guardiansVoted = recoveryRequest.guardianVoted.values();
        uint256 voteCount = guardiansVoted.length;
        for (uint256 i = 0; i < voteCount; i++) {
            recoveryRequest.guardianVoted.remove(guardiansVoted[i]);
        }
        delete recoveryRequests[account];
    }

    /**
     * @notice Toggles the kill switch on the manager
     * @dev Can only be called by the kill switch authorizer
     */
    function toggleKillSwitch() external onlyOwner {
        killSwitchEnabled = !killSwitchEnabled;
    }
}
