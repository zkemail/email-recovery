// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {PackedUserOperation} from "modulekit/external/ERC4337.sol";
import {EmailAccountRecovery} from "ether-email-auth/packages/contracts/src/EmailAccountRecovery.sol";

import {GuardianManager} from "./GuardianManager.sol";
import {RouterManager} from "./RouterManager.sol";
import {IZkEmailRecovery} from "../interfaces/IZkEmailRecovery.sol";

interface IRecoveryModule {
    function recover(address account, address newOwner) external;
}

contract ZkEmailRecovery is
    GuardianManager,
    RouterManager,
    EmailAccountRecovery,
    IZkEmailRecovery
{
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    /** Mapping of account address to recovery delay */
    mapping(address => RecoveryConfig) public recoveryConfigs;

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
     */
    function configureRecovery(
        address[] memory guardians,
        uint256[] memory weights,
        uint256 threshold,
        uint256 recoveryDelay,
        uint256 recoveryExpiry
    ) external {
        address account = msg.sender;

        setupGuardians(account, guardians, weights, threshold);

        if (recoveryRequests[account].totalWeight > 0) {
            revert RecoveryInProcess();
        }

        address router = deployRouterForAccount(account);

        recoveryConfigs[account] = RecoveryConfig(
            recoveryDelay,
            recoveryExpiry
        );

        emit RecoveryConfigured(account, recoveryDelay, recoveryExpiry, router);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IZkEmailRecovery
    function getRecoveryConfig(
        address account
    ) external view returns (RecoveryConfig memory) {
        return recoveryConfigs[account];
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
        templates[0] = new string[](11);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "to";
        templates[0][4] = "new";
        templates[0][5] = "owner";
        templates[0][6] = "{ethAddr}";
        templates[0][7] = "using";
        templates[0][8] = "recovery";
        templates[0][9] = "module";
        templates[0][10] = "{ethAddr}";
        return templates;
    }

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

        if (recoveryRequests[accountInEmail].totalWeight > 0) {
            revert RecoveryInProcess();
        }

        GuardianStorage memory guardianStorage = getGuardian(
            accountInEmail,
            guardian
        );
        if (guardianStorage.status != GuardianStatus.REQUESTED)
            revert InvalidGuardianStatus(
                guardianStorage.status,
                GuardianStatus.REQUESTED
            );

        _updateGuardian(
            accountInEmail,
            guardian,
            GuardianStorage(GuardianStatus.ACCEPTED, guardianStorage.weight)
        );
    }

    function processRecovery(
        address guardian,
        uint templateIdx,
        bytes[] memory subjectParams,
        bytes32
    ) internal override {
        if (guardian == address(0)) revert InvalidGuardian();
        if (templateIdx != 0) revert InvalidTemplateIndex();
        if (subjectParams.length != 3) revert InvalidSubjectParams();

        address accountInEmail = abi.decode(subjectParams[0], (address));
        address newOwnerInEmail = abi.decode(subjectParams[1], (address));
        address recoveryModuleInEmail = abi.decode(subjectParams[2], (address));

        GuardianStorage memory guardian = getGuardian(accountInEmail, guardian);
        if (guardian.status != GuardianStatus.ACCEPTED)
            revert InvalidGuardianStatus(
                guardian.status,
                GuardianStatus.ACCEPTED
            );
        if (newOwnerInEmail == address(0)) revert InvalidNewOwner();
        if (recoveryModuleInEmail == address(0)) revert InvalidRecoveryModule();

        RecoveryRequest storage recoveryRequest = recoveryRequests[
            accountInEmail
        ];

        recoveryRequest.totalWeight += guardian.weight;

        uint256 threshold = getGuardianConfig(accountInEmail).threshold;
        if (recoveryRequest.totalWeight >= threshold) {
            uint256 executeAfter = block.timestamp +
                recoveryConfigs[accountInEmail].recoveryDelay;
            uint256 executeBefore = block.timestamp +
                recoveryConfigs[accountInEmail].recoveryExpiry;

            recoveryRequest.executeAfter = executeAfter;
            recoveryRequest.executeBefore = executeBefore;
            recoveryRequest.newOwner = newOwnerInEmail;
            recoveryRequest.recoveryModule = recoveryModuleInEmail;

            emit RecoveryInitiated(accountInEmail, executeAfter);

            if (executeAfter == block.timestamp) {
                completeRecovery(accountInEmail);
            }
        }
    }

    function completeRecovery() public override {
        address account = getAccountForRouter(msg.sender);
        completeRecovery(account);
    }

    function completeRecovery(address account) public {
        RecoveryRequest memory recoveryRequest = recoveryRequests[account];

        uint256 threshold = getGuardianConfig(account).threshold;
        if (recoveryRequest.totalWeight < threshold)
            revert NotEnoughApprovals();

        if (block.timestamp < recoveryRequest.executeAfter)
            revert DelayNotPassed();

        if (block.timestamp >= recoveryRequest.executeBefore) {
            delete recoveryRequests[account];
            revert RecoveryRequestExpired();
        }

        delete recoveryRequests[account];

        IRecoveryModule(recoveryRequest.recoveryModule).recover(
            account,
            recoveryRequest.newOwner
        );

        emit RecoveryCompleted(account);
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
}
