// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { EmailAccountRecoveryNew } from "./experimental/EmailAccountRecoveryNew.sol";
import { IEmailRecoveryManager } from "./interfaces/IEmailRecoveryManager.sol";
import { IEmailRecoverySubjectHandler } from "./interfaces/IEmailRecoverySubjectHandler.sol";
import { IRecoveryModule } from "./interfaces/IRecoveryModule.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "./libraries/EnumerableGuardianMap.sol";
import { GuardianUtils } from "./libraries/GuardianUtils.sol";
import "forge-std/console2.sol";

/**
 * @title EmailRecoveryManager
 * @notice Provides a mechanism for account recovery using email guardians
 * @dev The underlying EmailAccountRecovery contract provides some base logic for deploying
 * guardian contracts and handling email verification.
 *
 * This contract defines a default implementation for email-based recovery. It is designed to
 * provide the core logic for email based account recovery that can be used across different account
 * implementations.
 *
 * EmailRecoveryManager relies on a dedicated recovery module to execute a recovery attempt. This
 * (EmailRecoveryManager) contract defines "what a valid recovery attempt is for an account", and
 * the recovery module defines “how that recovery attempt is executed on the account”.
 */
contract EmailRecoveryManager is EmailAccountRecoveryNew, Initializable, IEmailRecoveryManager {
    using GuardianUtils for mapping(address => GuardianConfig);
    using GuardianUtils for mapping(address => EnumerableGuardianMap.AddressToGuardianMap);
    using Strings for uint256;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * Minimum required time window between when a recovery attempt becomes valid and when it
     * becomes invalid
     */
    uint256 public constant MINIMUM_RECOVERY_WINDOW = 2 days;

    /**
     * The subject handler that returns and validates the subject templates
     */
    address public immutable subjectHandler;

    /**
     * The recovery module that is responsible for recovering an account
     */
    address public emailRecoveryModule;

    /**
     * Deployer address stored to prevent frontrunning at initialization
     */
    address private deployer;

    /**
     * Account address to recovery config
     */
    mapping(address account => RecoveryConfig recoveryConfig) internal recoveryConfigs;

    /**
     * Account address to recovery request
     */
    mapping(address account => RecoveryRequest recoveryRequest) internal recoveryRequests;

    /**
     * Account to guardian config
     */
    mapping(address account => GuardianConfig guardianConfig) internal guardianConfigs;

    /**
     * Account address to guardian address to guardian storage
     */
    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl,
        address _subjectHandler
    ) {
        verifierAddr = _verifier;
        dkimAddr = _dkimRegistry;
        emailAuthImplementationAddr = _emailAuthImpl;
        subjectHandler = _subjectHandler;
        if (_subjectHandler == address(0)) {
            revert InvalidSubjectHandler();
        }
        deployer = msg.sender;
    }

    function initialize(address _emailRecoveryModule) external initializer {
        if (msg.sender != deployer) {
            revert InitializerNotDeployer();
        }
        if (_emailRecoveryModule == address(0)) {
            revert InvalidRecoveryModule();
        }
        emailRecoveryModule = _emailRecoveryModule;
    }

    /**
     * @dev Modifier to check recovery status. Reverts if recovery is in process for the account
     */
    modifier onlyWhenNotRecovering() {
        if (recoveryRequests[msg.sender].currentWeight > 0) {
            revert RecoveryInProcess();
        }
        _;
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
     * @param account The address of the account for which the recovery request details are being
     * retrieved
     * @return RecoveryRequest The recovery request details for the specified account
     */
    function getRecoveryRequest(address account) external view returns (RecoveryRequest memory) {
        return recoveryRequests[account];
    }

    /**
     * @notice Returns a two-dimensional array of strings representing the subject templates for an
     * acceptance by a new guardian.
     * @dev This function is overridden from EmailAccountRecovery. It is also virtual so can be
     * re-implemented by inheriting contracts
     * to define different acceptance subject templates. This is useful for account implementations
     * which require different data
     * in the subject or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a subject template.
     */
    function acceptanceSubjectTemplates() public view override returns (string[][] memory) {
        return IEmailRecoverySubjectHandler(subjectHandler).acceptanceSubjectTemplates();
    }

    /**
     * @notice Returns a two-dimensional array of strings representing the subject templates for
     * email recovery.
     * @dev This function is overridden from EmailAccountRecovery. It is also virtual so can be
     * re-implemented by inheriting contracts
     * to define different recovery subject templates. This is useful for account implementations
     * which require different data
     * in the subject or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a subject template.
     */
    function recoverySubjectTemplates() public view override returns (string[][] memory) {
        return IEmailRecoverySubjectHandler(subjectHandler).recoverySubjectTemplates();
    }

    function extractRecoveredAccountFromAcceptanceSubject(
        bytes[] memory subjectParams,
        uint256 templateIdx
    )
        public
        view
        override
        returns (address)
    {
        return IEmailRecoverySubjectHandler(subjectHandler)
            .extractRecoveredAccountFromAcceptanceSubject(subjectParams, templateIdx);
    }

    function extractRecoveredAccountFromRecoverySubject(
        bytes[] memory subjectParams,
        uint256 templateIdx
    )
        public
        view
        override
        returns (address)
    {
        return IEmailRecoverySubjectHandler(subjectHandler)
            .extractRecoveredAccountFromRecoverySubject(subjectParams, templateIdx);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     CONFIGURE RECOVERY                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Configures recovery for the caller's account. This is the first core function
     * that must be called during the end-to-end recovery flow
     * @dev Can only be called once for configuration. Sets up the guardians, deploys a router
     * contract, and validates config parameters, ensuring that no recovery is in process
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
        external
    {
        address account = msg.sender;

        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        if (guardianConfigs[account].threshold > 0) {
            revert SetupAlreadyCalled();
        }

        setupGuardians(account, guardians, weights, threshold);

        if (IRecoveryModule(emailRecoveryModule).getAllowedValidators(account).length == 0) {
            revert RecoveryModuleNotInstalled();
        }

        RecoveryConfig memory recoveryConfig = RecoveryConfig(delay, expiry);
        updateRecoveryConfig(recoveryConfig);

        emit RecoveryConfigured(account, guardians.length);
    }

    /**
     * @notice Updates and validates the recovery configuration for the caller's account
     * @dev Validates and sets the new recovery configuration for the caller's account, ensuring
     * that no
     * recovery is in process. Reverts if the recovery module address is invalid, if the
     * delay is greater than the expiry, or if the recovery window is too short
     * @param recoveryConfig The new recovery configuration to be set for the caller's account
     */
    function updateRecoveryConfig(RecoveryConfig memory recoveryConfig)
        public
        onlyWhenNotRecovering
    {
        address account = msg.sender;

        if (guardianConfigs[account].threshold == 0) {
            revert AccountNotConfigured();
        }
        if (recoveryConfig.delay > recoveryConfig.expiry) {
            revert DelayMoreThanExpiry();
        }
        if (recoveryConfig.expiry - recoveryConfig.delay < MINIMUM_RECOVERY_WINDOW) {
            revert RecoveryWindowTooShort();
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
     * acceptance
     * flow is an important security feature to ensure that no typos are made when adding a guardian
     * and that the guardian explicitly consents to the role. Called as part of handleAcceptance
     * in EmailAccountRecovery
     * @param guardian The address of the guardian to be accepted
     * @param templateIdx The index of the template used for acceptance
     * @param subjectParams An array of bytes containing the subject parameters
     */
    function acceptGuardian(
        address guardian,
        uint256 templateIdx,
        bytes[] memory subjectParams,
        bytes32
    )
        internal
        override
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex();
        }

        address account = IEmailRecoverySubjectHandler(subjectHandler).validateAcceptanceSubject(
            templateIdx, subjectParams
        );

        if (recoveryRequests[account].currentWeight > 0) {
            revert RecoveryInProcess();
        }

        if (IRecoveryModule(emailRecoveryModule).getAllowedValidators(account).length == 0) {
            revert RecoveryModuleNotInstalled();
        }

        // This check ensures GuardianStatus is correct and also implicitly that the
        // account in email is a valid account
        GuardianStorage memory guardianStorage = getGuardian(account, guardian);
        if (guardianStorage.status != GuardianStatus.REQUESTED) {
            revert InvalidGuardianStatus(guardianStorage.status, GuardianStatus.REQUESTED);
        }

        guardiansStorage.updateGuardianStatus(account, guardian, GuardianStatus.ACCEPTED);

        emit GuardianAccepted(account, guardian);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      HANDLE RECOVERY                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Processes a recovery request for a given account. This is the third core function
     * that must be called during the end-to-end recovery flow
     * @dev Reverts if the guardian address is invalid, if the template index is not zero, or if the
     * guardian status is not accepted
     * @param guardian The address of the guardian initiating the recovery
     * @param templateIdx The index of the template used for the recovery request
     * @param subjectParams An array of bytes containing the subject parameters
     */
    function processRecovery(
        address guardian,
        uint256 templateIdx,
        bytes[] memory subjectParams,
        bytes32
    )
        internal
        override
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex();
        }

        (address account, string memory calldataHashString) = IEmailRecoverySubjectHandler(
            subjectHandler
        ).validateRecoverySubject(templateIdx, subjectParams, address(this));

        if (IRecoveryModule(emailRecoveryModule).getAllowedValidators(account).length == 0) {
            revert RecoveryModuleNotInstalled();
        }

        // This check ensures GuardianStatus is correct and also implicitly that the
        // account in email is a valid account
        GuardianStorage memory guardianStorage = getGuardian(account, guardian);
        if (guardianStorage.status != GuardianStatus.ACCEPTED) {
            revert InvalidGuardianStatus(guardianStorage.status, GuardianStatus.ACCEPTED);
        }

        RecoveryRequest storage recoveryRequest = recoveryRequests[account];

        recoveryRequest.currentWeight += guardianStorage.weight;

        uint256 threshold = guardianConfigs[account].threshold;
        if (recoveryRequest.currentWeight >= threshold) {
            uint256 executeAfter = block.timestamp + recoveryConfigs[account].delay;
            uint256 executeBefore = block.timestamp + recoveryConfigs[account].expiry;

            recoveryRequest.executeAfter = executeAfter;
            recoveryRequest.executeBefore = executeBefore;
            recoveryRequest.calldataHashString = calldataHashString;

            emit RecoveryProcessed(account, executeAfter, executeBefore);
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
     * and the request has not expired. Triggers the recovery module to perform the recovery. The
     * recovery module trusts that this contract has validated the recovery attempt. Deletes the
     * recovery
     * request but recovery config state is maintained so future recovery requests can be made
     * without having to reconfigure everything
     * @param account The address of the account for which the recovery is being completed
     */
    function completeRecovery(address account, bytes memory recoveryCalldata) public override {
        if (account == address(0)) {
            revert InvalidAccountAddress();
        }
        RecoveryRequest memory recoveryRequest = recoveryRequests[account];

        uint256 threshold = guardianConfigs[account].threshold;
        if (recoveryRequest.currentWeight < threshold) {
            revert NotEnoughApprovals();
        }

        if (block.timestamp < recoveryRequest.executeAfter) {
            revert DelayNotPassed();
        }

        if (block.timestamp >= recoveryRequest.executeBefore) {
            revert RecoveryRequestExpired();
        }

        delete recoveryRequests[account];

        bytes32 calldataHash = keccak256(recoveryCalldata);
        string memory calldataHashString = uint256(calldataHash).toHexString(32);

        if (!Strings.equal(calldataHashString, recoveryRequest.calldataHashString)) {
            revert InvalidCalldataHash();
        }

        IRecoveryModule(emailRecoveryModule).recover(account, recoveryCalldata);

        emit RecoveryCompleted(account);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CANCEL/DE-INIT LOGIC                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Cancels the recovery request for the caller's account
     * @dev Deletes the current recovery request associated with the caller's account
     */
    function cancelRecovery() external virtual {
        delete recoveryRequests[msg.sender];
        emit RecoveryCancelled(msg.sender);
    }

    /**
     * @notice Removes all state related to an account. Must be called from a configured recovery
     * module
     * @dev In order to prevent unexpected behaviour when reinstalling account modules, the module
     * should be deinitialized. This should include remove state accociated with an account.
     * @param account The account to delete state for
     */
    function deInitRecoveryFromModule(address account) external {
        if (emailRecoveryModule != msg.sender) {
            revert NotRecoveryModule();
        }

        if (recoveryRequests[account].currentWeight > 0) {
            revert RecoveryInProcess();
        }

        delete recoveryConfigs[account];
        delete recoveryRequests[account];

        guardiansStorage.removeAllGuardians(account);
        delete guardianConfigs[account];

        emit RecoveryDeInitialized(account);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       GUARDIAN LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function getGuardianConfig(address account) external view returns (GuardianConfig memory) {
        return guardianConfigs[account];
    }

    function getGuardian(
        address account,
        address guardian
    )
        public
        view
        returns (GuardianStorage memory)
    {
        return guardiansStorage.getGuardianStorage(account, guardian);
    }

    function setupGuardians(
        address account,
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold
    )
        internal
    {
        guardianConfigs.setupGuardians(guardiansStorage, account, guardians, weights, threshold);
    }

    function addGuardian(address guardian, uint256 weight) external onlyWhenNotRecovering {
        guardiansStorage.addGuardian(guardianConfigs, msg.sender, guardian, weight);
    }

    function removeGuardian(address guardian) external onlyWhenNotRecovering {
        guardiansStorage.removeGuardian(guardianConfigs, msg.sender, guardian);
    }

    function changeThreshold(uint256 threshold) external onlyWhenNotRecovering {
        guardianConfigs.changeThreshold(msg.sender, threshold);
    }
}
