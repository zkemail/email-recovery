// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC7579ExecutorBase} from "modulekit/Modules.sol";
import {PackedUserOperation} from "modulekit/external/ERC4337.sol";
import {EmailAccountRecovery} from "ether-email-auth/packages/contracts/src/EmailAccountRecovery.sol";

import {GuardianManager} from "./GuardianManager.sol";
import {RouterManager} from "./RouterManager.sol";
import {IZkEmailRecovery} from "./interfaces/IZkEmailRecovery.sol";

interface IOwnableValidator {
    function changeOwner(address newOwner) external;
}

contract ZkEmailRecovery is
    GuardianManager,
    RouterManager,
    EmailAccountRecovery,
    IZkEmailRecovery,
    ERC7579ExecutorBase
{
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /** Mapping of account address to recovery delay */
    mapping(address => uint256) public recoveryDelays;

    /** Mapping of account address to recovery request */
    mapping(address => RecoveryRequest) public recoveryRequests;

    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl
    ) {
        verifierAddr = _verifier;
        dkimAddr = _dkimRegistry;
        emailAuthImplementationAddr = _emailAuthImpl;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        address account = msg.sender;
        (
            address[] memory guardians,
            uint256 recoveryDelay,
            uint256 threshold
        ) = abi.decode(data, (address[], uint256, uint256));

        setupGuardians(account, guardians, threshold);

        if (recoveryRequests[account].executeAfter > 0) {
            revert RecoveryAlreadyInitiated();
        }

        address router = deployRouterForAccount(account);

        recoveryDelays[account] = recoveryDelay;

        emit RecoveryConfigured(
            account,
            guardians.length,
            threshold,
            recoveryDelay,
            router
        );
    }

    /**
     * De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {
        // TODO:
    }

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return getGuardianConfig(smartAccount).guardianCount > 0;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IZkEmailRecovery
    function getRecoveryDelay(address account) external view returns (uint256) {
        return recoveryDelays[account];
    }

    /// @inheritdoc IZkEmailRecovery
    function getRecoveryRequest(
        address account
    ) external view returns (RecoveryRequest memory) {
        return recoveryRequests[account];
    }

    /// @inheritdoc EmailAccountRecovery
    function acceptanceSubjectTemplates()
        public
        pure
        override
        returns (string[][] memory)
    {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](5);
        templates[0][0] = "Accept";
        templates[0][1] = "guardian";
        templates[0][2] = "request";
        templates[0][3] = "for";
        templates[0][4] = "{ethAddr}";
        return templates;
    }

    /// @inheritdoc EmailAccountRecovery
    function recoverySubjectTemplates()
        public
        pure
        override
        returns (string[][] memory)
    {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](9);
        templates[0][0] = "Update";
        templates[0][1] = "owner";
        templates[0][2] = "from";
        templates[0][3] = "{ethAddr}";
        templates[0][4] = "to";
        templates[0][5] = "{ethAddr}";
        templates[0][6] = "on";
        templates[0][7] = "account";
        templates[0][8] = "{ethAddr}";
        return templates;
    }

    // TODO: add natspec to interface or inherit from EmailAccountRecovery
    function acceptGuardian(
        address guardian,
        uint templateIdx,
        bytes[] memory subjectParams,
        bytes32
    ) internal override {
        if (guardian == address(0)) revert InvalidGuardian();
        if (templateIdx != 0) revert InvalidTemplateIndex();
        if (subjectParams.length != 1) revert InvalidSubjectParams();

        address accountInEmail = abi.decode(subjectParams[0], (address));

        address accountForRouter = getAccountForRouter(msg.sender);
        if (accountForRouter != accountInEmail)
            revert InvalidAccountForRouter();

        if (!isGuardian(guardian, accountInEmail))
            revert GuardianInvalidForAccountInEmail();

        GuardianStatus guardianStatus = getGuardianStatus(
            accountInEmail,
            guardian
        );
        if (guardianStatus == GuardianStatus.ACCEPTED)
            revert GuardianAlreadyAccepted();

        updateGuardian(accountInEmail, guardian, GuardianStatus.ACCEPTED);
    }

    // TODO: add natspec to interface or inherit from EmailAccountRecovery
    function processRecovery(
        address guardian,
        uint templateIdx,
        bytes[] memory subjectParams,
        bytes32
    ) internal override {
        if (guardian == address(0)) revert InvalidGuardian();
        if (templateIdx != 0) revert InvalidTemplateIndex();
        if (subjectParams.length != 3) revert InvalidSubjectParams();

        address ownerToSwapInEmail = abi.decode(subjectParams[0], (address));
        address newOwnerInEmail = abi.decode(subjectParams[1], (address));
        address accountInEmail = abi.decode(subjectParams[2], (address));

        address accountForRouter = getAccountForRouter(msg.sender);
        if (accountForRouter != accountInEmail)
            revert InvalidAccountForRouter();

        if (!isGuardian(guardian, accountInEmail))
            revert GuardianInvalidForAccountInEmail();

        GuardianStatus guardianStatus = getGuardianStatus(
            accountInEmail,
            guardian
        );
        if (guardianStatus == GuardianStatus.REQUESTED)
            revert GuardianHasNotAccepted();

        // bool isExistingOwner = ISafe(accountInEmail).isOwner(newOwnerInEmail); // FIXME: re-add check if needed
        // if (isExistingOwner) revert InvalidNewOwner();

        RecoveryRequest memory recoveryRequest = recoveryRequests[
            accountInEmail
        ];
        if (recoveryRequest.executeAfter > 0) {
            revert RecoveryAlreadyInitiated();
        }

        recoveryRequests[accountInEmail].approvalCount++;
        recoveryRequests[accountInEmail].recoveryData = abi.encode(
            newOwnerInEmail
        );

        uint256 threshold = getGuardianConfig(accountInEmail).threshold;
        if (recoveryRequests[accountInEmail].approvalCount >= threshold) {
            uint256 executeAfter = block.timestamp +
                recoveryDelays[accountInEmail];

            recoveryRequests[accountInEmail].executeAfter = executeAfter;

            emit RecoveryInitiated(
                accountInEmail,
                newOwnerInEmail,
                executeAfter
            );
        }
    }

    // TODO: add natspec to interface or inherit from EmailAccountRecovery
    function completeRecovery() public override {
        address account = getAccountForRouter(msg.sender);

        RecoveryRequest memory recoveryRequest = recoveryRequests[account];

        uint256 threshold = getGuardianConfig(account).threshold;
        if (recoveryRequest.approvalCount < threshold)
            revert NotEnoughApprovals();

        if (block.timestamp < recoveryRequest.executeAfter)
            revert DelayNotPassed();

        delete recoveryRequests[account];

        changeOwner(account, recoveryRequest.recoveryData);
    }

    function changeOwner(address account, bytes memory data) private {
        address newOwner = abi.decode(data, (address));

        IOwnableValidator(account).changeOwner(newOwner);

        // TODO: define this outside of interface as newOwner is account implementation specific?
        emit RecoveryCompleted(account, newOwner);
    }

    /// @inheritdoc IZkEmailRecovery
    function cancelRecovery() external {
        address account = msg.sender;
        delete recoveryRequests[account];
        emit RecoveryCancelled(account);
    }

    /// @inheritdoc IZkEmailRecovery
    function updateRecoveryDelay(uint256 recoveryDelay) external {
        // TODO: add implementation
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "ZkEmailRecovery";
    }

    /**
     * The version of the module
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    /**
     * Check if the module is of a certain type
     * @param typeID The type ID to check
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(
        uint256 typeID
    ) external pure override returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
