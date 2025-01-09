//SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAccountRecovery } from
    "@zk-email/ether-email-auth-contracts/src/EmailAccountRecovery.sol";
import { SimpleRecoveryVerifier } from
    "../EOA712Verifier.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { IEmailRecoveryCommandHandler } from "../../interfaces/IEmailRecoveryCommandHandler.sol";
import "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { SimpleGuardianManager } from "../SimpleGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "../../libraries/EnumerableGuardianMap.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@zk-email/ether-email-auth-contracts/src/libraries/StringUtils.sol";
import { ISimpleRecoveryModuleManager } from "../interfaces/ISimpleRecoveryModuleManager.sol";

/**
 * @title SimpleRecoveryModuleManager
 * @notice A simplified recovery module for ERC7579 accounts supporting multiple verification methods
 */
abstract contract SimpleRecoveryModuleManager is SimpleRecoveryVerifier, EmailAccountRecovery, Ownable, SimpleGuardianManager, ISimpleRecoveryModuleManager {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    using EnumerableSet for EnumerableSet.AddressSet;
    uint256 public constant MINIMUM_RECOVERY_WINDOW = 2 days;
    uint256 public immutable minimumDelay;

    address public immutable commandHandler;
    uint public constant CANCEL_EXPIRED_RECOVERY_COOLDOWN = 1 days;

    bool public killSwitchEnabled;
    mapping(address account => RecoveryConfig recoveryConfig) internal recoveryConfigs;
    mapping(address account => RecoveryRequest recoveryRequest) internal recoveryRequests;

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
        if (_emailAuthImpl == address(0)) {
            revert InvalidEmailAuthImpl();
        }
        if (_dkimRegistry == address(0)) {
            revert InvalidDKIMRegistry();
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
    /*                          FUNCTIONS                         */
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
    function getRecoveryRequest(address account) external view returns (
        uint256 executeAfter,
        uint256 executeBefore,
        uint256 currentWeight,
        bytes32 recoveryDataHash
    ) {
        return (
            recoveryRequests[account].executeAfter,
            recoveryRequests[account].executeBefore,
            recoveryRequests[account].currentWeight,
            recoveryRequests[account].recoveryDataHash
        );
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
        GuardianType[] memory guardianTypes,
        uint256 threshold,
        uint256 delay,
        uint256 expiry
    ) internal onlyWhenActive {
        address account = msg.sender;

        if (guardianConfigs[account].threshold > 0) {
            revert SetupAlreadyCalled();
        }
        (uint256 guardianCount, uint256 totalWeight) = setupGuardians(account, guardians, weights, guardianTypes, threshold);
        RecoveryConfig memory recoveryConfig = RecoveryConfig(delay, expiry);
    
        if (guardianConfigs[account].threshold == 0) {
            revert AccountNotConfigured();
        }
        if (recoveryConfig.delay < minimumDelay) {
            revert DelayLessThanMinimumDelay(recoveryConfig.delay, minimumDelay);
        }
        if (recoveryConfig.expiry < recoveryConfig.delay + MINIMUM_RECOVERY_WINDOW) {
            revert RecoveryWindowTooShort(recoveryConfig.expiry - recoveryConfig.delay);
        }
        if (recoveryConfig.delay > recoveryConfig.expiry) {
            revert DelayMoreThanExpiry(recoveryConfig.delay, recoveryConfig.expiry);
        }
        recoveryConfigs[account] = recoveryConfig;
        emit RecoveryConfigured(account, guardianCount, totalWeight, threshold);
    }

 /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
/*                     HANDLE ACCEPTANCE                      */
/*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´`*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

/**
 * @notice Handles the acceptance of a recovery request by a guardian, validating the request 
 * and updating the guardian's status.
 * 
 * This function verifies whether the guardian is an EOA or email-verified guardian:
 *  - If EOA, it verifies the signature.
 *  - If email-verified, it computes the email-auth address and deploys the proxy if needed.
 *    It also initializes the DKIM registry and verifier and inserts the acceptance/recovery templates.
 * 
 * @param emailAuthMsg The email authentication message containing the command parameters and proof.
 * @param templateIdx The index of the command template used in the acceptance process.
 * @param signature The signature of the guardian to validate the acceptance command.
 */
function handleAcceptanceV2(
    EmailAuthMsg memory emailAuthMsg,
    uint templateIdx,
    bytes memory signature
) external {
    address recoveredAccount = extractRecoveredAccountFromAcceptanceCommand(
        emailAuthMsg.commandParams,
        templateIdx
    );
    
    bool isEOAGuardian = emailAuthMsg.proof.accountSalt == bytes32(0);
    address guardian;
    if (isEOAGuardian) {
        guardian = verifyEOAGuardian(
            recoveredAccount,
            templateIdx,
            emailAuthMsg.commandParams,
            signature
        );
    } else {
        guardian = computeEmailAuthAddress(
            recoveredAccount,
            emailAuthMsg.proof.accountSalt
        );
              
        EmailAuth guardianEmailAuth;
        if (guardian.code.length == 0) {
            address proxyAddress = deployEmailAuthProxy(
                recoveredAccount,
                emailAuthMsg.proof.accountSalt
            );
            guardianEmailAuth = EmailAuth(proxyAddress);
            guardianEmailAuth.initDKIMRegistry(dkim());
            guardianEmailAuth.initVerifier(verifier());
            for (
                uint idx = 0;
                idx < acceptanceCommandTemplates().length;
                idx++
            ) {
                guardianEmailAuth.insertCommandTemplate(
                    computeAcceptanceTemplateId(idx),
                    acceptanceCommandTemplates()[idx]
                );
            }
            for (uint idx = 0; idx < recoveryCommandTemplates().length; idx++) {
                guardianEmailAuth.insertCommandTemplate(
                    computeRecoveryTemplateId(idx),
                    recoveryCommandTemplates()[idx]
                );
            }
        } else {
            guardianEmailAuth = EmailAuth(payable(address(guardian)));
            require(
                guardianEmailAuth.controller() == address(this),
                "invalid controller"
            );
        }

        guardianEmailAuth.authEmail(emailAuthMsg);
    }
    GuardianStorage memory guardianStorage = getGuardian(recoveredAccount, guardian);
    updateGuardianStatus(recoveredAccount, guardian, GuardianStatus.ACCEPTED);
    guardianConfigs[recoveredAccount].acceptedWeight += guardianStorage.weight;

    emit GuardianAccepted(recoveredAccount, guardian);
}

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
        templateIdx,
        commandParams
    );
    GuardianStorage memory guardianStorage = getGuardian(account, guardian);
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
    bytes32
) internal override onlyWhenActive {
    address account = IEmailRecoveryCommandHandler(commandHandler).validateRecoveryCommand(
        templateIdx,
        commandParams
    );

    if (!isActivated(account)) {
        revert RecoveryIsNotActivated();
    }

    GuardianConfig memory guardianConfig = guardianConfigs[account];
    if (guardianConfig.threshold > guardianConfig.acceptedWeight) {
        revert ThresholdExceedsAcceptedWeight(guardianConfig.threshold, guardianConfig.acceptedWeight);
    }

    // This check ensures GuardianStatus is correct and also implicitly that the
    // account in the email is a valid account
    GuardianStorage memory guardianStorage = getGuardian(account, guardian);
    if (guardianStorage.status != GuardianStatus.ACCEPTED) {
        revert InvalidGuardianStatus();
    }

    RecoveryRequest storage recoveryRequest = recoveryRequests[account];
    bytes32 recoveryDataHash = StringUtils.hexToBytes32(abi.decode(commandParams[1], (string)));
    
    if (hasGuardianVoted(account, guardian)) {
        revert GuardianAlreadyVoted();
    }

    if (recoveryRequest.recoveryDataHash == bytes32(0)) {
        recoveryRequest.recoveryDataHash = recoveryDataHash;
        uint256 executeBefore = block.timestamp + recoveryConfigs[account].expiry;
        recoveryRequest.executeBefore = executeBefore;
        emit RecoveryRequestStarted(account, guardian, executeBefore, recoveryDataHash);
    }

    if (recoveryRequest.recoveryDataHash != recoveryDataHash) {
        revert InvalidRecoveryDataHash();
    }

    recoveryRequest.currentWeight += guardianStorage.weight;
    recoveryRequest.guardianVoted.add(guardian);
    emit GuardianVoted(account, guardian);

    if (recoveryRequest.currentWeight >= guardianConfig.threshold) {
        uint256 executeAfter = block.timestamp + recoveryConfigs[account].delay;
        recoveryRequest.executeAfter = executeAfter;
        emit RecoveryRequestComplete(account, guardian, executeAfter, recoveryRequest.executeBefore, recoveryDataHash);
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
) external override onlyWhenActive {
    if (account == address(0)) {
        revert InvalidAccountAddress();
    }

    RecoveryRequest storage recoveryRequest = recoveryRequests[account];
    if (guardianConfigs[account].threshold == 0) {
        revert NoRecoveryConfigured();
    }
    if (recoveryRequest.currentWeight < guardianConfigs[account].threshold) {
        revert NotEnoughApprovals();
    }
    if (block.timestamp < recoveryRequest.executeAfter) {
        revert DelayNotPassed(block.timestamp, recoveryRequest.executeAfter);
    }
    if (block.timestamp >= recoveryRequest.executeBefore) {
        revert RecoveryRequestExpired();
    }

    recover(account, recoveryData);
    exitandclearRecovery(account);
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
function recover(
    address account,
    bytes calldata recoveryData
) internal virtual;

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
function deInitRecoveryModule(
    address account
) internal onlyWhenNotRecovering {
    delete recoveryConfigs[account];
    exitandclearRecovery(account);
    delete guardianConfigs[account];

    emit RecoveryDeInitialized(account);
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
            account,
            block.timestamp,
            recoveryRequests[account].executeBefore
        );
    }
    
    exitandclearRecovery(account);
    emit RecoveryCancelled(account);
}

/**
 * @notice Exits and clears the ongoing recovery process for a specified account.
 * 
 * This function cancels the recovery process if the sender has initiated one.
 * It removes all guardian votes associated with the recovery request and deletes the request.
 * 
 * @dev Emits a `RecoveryCancelled` event upon successful cancellation.
 * Reverts if no recovery process is currently active for the caller.
 * 
 * @param account The address of the account for which the recovery process is being cleared.
 */
function exitandclearRecovery(address account) public {
    if (recoveryRequests[msg.sender].currentWeight == 0) {
        revert NoRecoveryInProcess();
    }
    RecoveryRequest storage recoveryRequest = recoveryRequests[account];
    address[] memory guardiansVoted = recoveryRequest.guardianVoted.values();
    uint256 voteCount = guardiansVoted.length;
    
    for (uint256 i = 0; i < voteCount; i++) {
        recoveryRequest.guardianVoted.remove(guardiansVoted[i]);
    }
    
    delete recoveryRequests[account];
    emit RecoveryCancelled(account);
}

/**
 * @notice Toggles the kill switch on the manager
 * @dev Can only be called by the kill switch authorizer
 */
function toggleKillSwitch() external onlyOwner {
    killSwitchEnabled = !killSwitchEnabled;
}
}
