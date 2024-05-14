// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.0;

import {IGuardianManager} from "../interfaces/IGuardianManager.sol";
// TODO: validate weights

abstract contract GuardianManager is IGuardianManager {
    /** Account to guardian to guardian status */
    mapping(address => mapping(address => GuardianStorage))
        internal guardianStorage;

    /** Account to guardian storage */
    mapping(address => GuardianConfig) internal guardianConfigs;

    /**
     * @notice Sets the initial storage of the contract.
     * @param account The account.
     */
    function setupGuardians(
        address account,
        address[] memory _guardians,
        uint256[] memory weights,
        uint256 threshold
    ) internal {
        uint256 guardianCount = _guardians.length;
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function can only be called once.
        if (guardianConfigs[account].threshold > 0) revert SetupAlreadyCalled();

        // Validate that threshold is smaller than number of added owners.
        if (threshold > guardianCount)
            revert ThresholdCannotExceedGuardianCount();

        // There has to be at least one Account owner.
        if (threshold == 0) revert ThresholdCannotBeZero();

        for (uint256 i = 0; i < guardianCount; i++) {
            address _guardian = _guardians[i];
            uint256 weight = weights[i];
            GuardianStorage memory _guardianStorage = guardianStorage[account][
                _guardian
            ];

            if (_guardian == address(0) || _guardian == address(this))
                revert InvalidGuardianAddress();

            if (_guardianStorage.status == GuardianStatus.REQUESTED)
                revert AddressAlreadyRequested();

            if (_guardianStorage.status == GuardianStatus.ACCEPTED)
                revert AddressAlreadyGuardian();

            guardianStorage[account][_guardian] = GuardianStorage(
                GuardianStatus.REQUESTED,
                weight
            );
        }

        guardianConfigs[account] = GuardianConfig(guardianCount, threshold);
    }

    // @inheritdoc IGuardianManager
    function updateGuardian(
        address guardian,
        GuardianStorage memory _guardianStorage
    ) external override onlyConfiguredAccount {
        _updateGuardian(msg.sender, guardian, _guardianStorage);
    }

    function _updateGuardian(
        address account,
        address guardian,
        GuardianStorage memory _guardianStorage
    ) internal {
        if (account == address(0) || account == address(this))
            revert InvalidAccountAddress();

        if (guardian == address(0) || guardian == address(this))
            revert InvalidGuardianAddress();

        GuardianStorage memory oldGuardian = guardianStorage[account][guardian];
        if (_guardianStorage.status == oldGuardian.status)
            revert GuardianStatusMustBeDifferent();

        guardianStorage[account][guardian] = GuardianStorage(
            _guardianStorage.status,
            _guardianStorage.weight
        );
    }

    // @inheritdoc IGuardianManager
    function addGuardianWithThreshold(
        address guardian,
        uint256 weight,
        uint256 threshold
    ) public override onlyConfiguredAccount {
        address account = msg.sender;
        GuardianStorage memory _guardianStorage = guardianStorage[account][
            guardian
        ];

        // Guardian address cannot be null, the sentinel or the Account itself.
        if (guardian == address(0) || guardian == address(this))
            revert InvalidGuardianAddress();

        if (_guardianStorage.status == GuardianStatus.REQUESTED)
            revert AddressAlreadyRequested();

        if (_guardianStorage.status == GuardianStatus.ACCEPTED)
            revert AddressAlreadyGuardian();

        guardianStorage[account][guardian] = GuardianStorage(
            GuardianStatus.REQUESTED,
            weight
        );
        guardianConfigs[account].guardianCount++;

        emit AddedGuardian(guardian);

        // Change threshold if threshold was changed.
        if (guardianConfigs[account].threshold != threshold)
            _changeThreshold(account, threshold);
    }

    // @inheritdoc IGuardianManager
    function removeGuardian(
        address guardian,
        uint256 threshold
    ) public override onlyConfiguredAccount {
        address account = msg.sender;
        // Only allow to remove an guardian, if threshold can still be reached.
        if (guardianConfigs[account].threshold - 1 < threshold)
            revert ThresholdCannotExceedGuardianCount();

        if (guardian == address(0)) revert InvalidGuardianAddress();

        guardianStorage[account][guardian].status = GuardianStatus.NONE;
        guardianConfigs[account].guardianCount--;

        emit RemovedGuardian(guardian);

        // Change threshold if threshold was changed.
        if (guardianConfigs[account].threshold != threshold)
            _changeThreshold(account, threshold);
    }

    // @inheritdoc IGuardianManager
    function swapGuardian(
        address oldGuardian,
        address newGuardian
    ) public override onlyConfiguredAccount {
        address account = msg.sender;

        GuardianStatus newGuardianStatus = guardianStorage[account][newGuardian]
            .status;

        if (
            newGuardian == address(0) ||
            newGuardian == address(this) ||
            newGuardian == oldGuardian
        ) revert InvalidGuardianAddress();

        if (newGuardianStatus == GuardianStatus.REQUESTED)
            revert AddressAlreadyRequested();

        if (newGuardianStatus == GuardianStatus.ACCEPTED)
            revert AddressAlreadyGuardian();

        GuardianStorage memory oldGuardianStorage = guardianStorage[account][
            oldGuardian
        ];

        if (oldGuardianStorage.status == GuardianStatus.REQUESTED)
            revert AddressAlreadyRequested();

        guardianStorage[account][newGuardian] = GuardianStorage(
            GuardianStatus.REQUESTED,
            oldGuardianStorage.weight
        );
        guardianStorage[account][oldGuardian] = GuardianStorage(
            GuardianStatus.NONE,
            0
        );

        emit RemovedGuardian(oldGuardian);
        emit AddedGuardian(newGuardian);
    }

    // @inheritdoc IGuardianManager
    function changeThreshold(
        uint256 threshold
    ) public override onlyConfiguredAccount {
        address account = msg.sender;
        _changeThreshold(account, threshold);
    }

    function _changeThreshold(address account, uint256 threshold) private {
        // Validate that threshold is smaller than number of guardians.
        if (threshold > guardianConfigs[account].guardianCount)
            revert ThresholdCannotExceedGuardianCount();

        // There has to be at least one Account guardian.
        if (threshold == 0) revert ThresholdCannotBeZero();

        guardianConfigs[account].threshold = threshold;
        emit ChangedThreshold(threshold);
    }

    // @inheritdoc IGuardianManager
    function getGuardianConfig(
        address account
    ) public view override returns (GuardianConfig memory) {
        return guardianConfigs[account];
    }

    // @inheritdoc IGuardianManager
    function getGuardian(
        address account,
        address guardian
    ) public view returns (GuardianStorage memory) {
        return guardianStorage[account][guardian];
    }

    // @inheritdoc IGuardianManager
    function isGuardian(
        address guardian,
        address account
    ) public view override returns (bool) {
        return guardianStorage[account][guardian].status != GuardianStatus.NONE;
    }

    modifier onlyConfiguredAccount() {
        checkConfigured(msg.sender);
        _;
    }

    function checkConfigured(address account) internal {
        bool authorized = guardianConfigs[account].guardianCount > 0;
        if (!authorized) revert AccountNotConfigured();
    }
}
