// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "./libraries/EnumerableGuardianMap.sol";
import { IGuardianManager } from "./interfaces/IGuardianManager.sol";
import { IRecoveryManager } from "./interfaces/IRecoveryManager.sol";

/**
 * @title GuardianManager
 * @notice A contract to manage guardian configurations for accounts
 */
abstract contract GuardianManager is IGuardianManager {
    using EnumerableGuardianMap for EnumerableGuardianMap.Bytes32ToGuardianMap;

    /**
     * Account to guardian config
     */
    mapping(address account => GuardianManager.GuardianConfig guardianConfig) internal
        guardianConfigs;

    /**
     * Account address to guardian storage
     */
    mapping(address account => EnumerableGuardianMap.Bytes32ToGuardianMap guardian) internal
        guardiansStorage;

    /**
     * Account address to guardian verifier status. whether it is supported or not.
     */
    mapping(address account => mapping(address _guardianVerifier => bool isGuardianVerifierSupported)) internal isGuardianVerifier;

    /**
     * Account address to guardianHash to guardian verifier.
     */
    mapping(address account => mapping(bytes32 guardianHash => address _guardianVerifier)) internal guardianVerifier;



    /**
     * @notice Modifier to check recovery status. Reverts if recovery is in process for the account
     */
    modifier onlyWhenNotRecovering() {
        (,, uint256 currentWeight,) =
            IRecoveryManager(address(this)).getRecoveryRequest(msg.sender);
        if (currentWeight > 0) {
            revert RecoveryInProcess();
        }
        _;
    }

    /**
     * @notice Modifier to check if the kill switch has been enabled
     * @dev This impacts EmailRecoveryManager & GuardianManager
     */
    modifier onlyWhenActive() {
        bool killSwitchEnabled = IRecoveryManager(address(this)).killSwitchEnabled();
        if (killSwitchEnabled) {
            revert KillSwitchEnabled();
        }
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       GUARDIAN LOGIC                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Retrieves the guardian configuration for a given account
     * @param account The address of the account for which the guardian configuration is being
     * retrieved
     * @return GuardianConfig The guardian configuration for the specified account
     */
    function getGuardianConfig(address account) public view returns (GuardianConfig memory) {
        return guardianConfigs[account];
    }

    /**
     * @notice Retrieves the guardian storage details for a given guardian and account
     * @param account The address of the account associated with the guardian
     * @param guardian The identifier hash of the guardian
     * @return GuardianStorage The guardian storage details for the specified guardian and account
     */
    function getGuardian(
        address account,
        bytes32 guardian
    )
        public
        view
        returns (GuardianStorage memory)
    {
        return guardiansStorage[account].get(guardian);
    }

    /**
     * @notice Sets up guardians for a given account with specified weights and threshold
     * @dev This function can only be called once and ensures the guardians, weights, and threshold
     * are correctly configured
     * @param account The address of the account for which guardians are being set up
     * @param guardians An array of guardian identifier hashes
     * @param guardianVerifiers An array of guardian verifiers
     * @param weights An array of weights corresponding to each guardian
     * @param threshold The threshold weight required for guardians to approve recovery attempts
     */
    function setupGuardians(
        address account,
        bytes32[] memory guardians,
        address[] memory guardianVerifiers,
        uint256[] memory weights,
        uint256 threshold
    )
        internal
        returns (uint256, uint256)
    {
        uint256 guardianCount = guardians.length;

        if (guardianCount != weights.length) {
            revert IncorrectNumberOfWeights(guardianCount, weights.length);
        }

        if (guardianCount != guardianVerifiers.length) {
            revert IncorrectNumberOfGuardianVerifiers(guardianCount, guardianVerifiers.length);
        }

        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }

        for (uint256 i = 0; i < guardianCount; i++) {
            _addGuardian(account, guardians[i], guardianVerifiers[i], weights[i]);
        }

        uint256 totalWeight = guardianConfigs[account].totalWeight;
        if (threshold > totalWeight) {
            revert ThresholdExceedsTotalWeight(threshold, totalWeight);
        }

        guardianConfigs[account].threshold = threshold;

        return (guardianCount, totalWeight);
    }

    /**
     * @notice Adds a guardian for the caller's account with a specified weight
     * @dev This function can only be called by the account associated with the guardian and only if
     * no recovery is in process
     * @param guardian The identifier hash of the guardian to be added
     * @param _guardianVerifier The address of the guardian verifier
     * @param weight The weight assigned to the guardian
     */
    function addGuardian(
        bytes32 guardian,
        address _guardianVerifier,
        uint256 weight
    )
        public
        onlyWhenNotRecovering
        onlyWhenActive
    {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function should be called first
        if (guardianConfigs[msg.sender].threshold == 0) {
            revert SetupNotCalled();
        }

        _addGuardian(msg.sender, guardian, _guardianVerifier, weight);
    }

    /**
     * @notice Internal fucntion to add a guardian for the caller's account with a specified weight
     * @dev A guardian is added, but not accepted after this function has been called
     * @param account The address of the account associated with the guardian
     * @param guardian The identifier hash of the guardian to be added
     * @param _guardianVerifier The address of the guardian verifier
     * @param weight The weight assigned to the guardian
     */
    function _addGuardian(
        address account, 
        bytes32 guardian, 
        address _guardianVerifier, 
        uint256 weight
    ) internal {
        if (guardian == keccak256(bytes("")) || guardian == keccak256(abi.encode(account))) {
            revert InvalidGuardianAddress(guardian);
        }

        if (weight == 0) {
            revert InvalidGuardianWeight();
        }

        bool success = guardiansStorage[account].set({
            key: guardian,
            value: GuardianStorage(GuardianStatus.REQUESTED, weight)
        });
        if (!success) {
            revert AddressAlreadyGuardian();
        }

        setAccountGuardianVerifier(guardian, _guardianVerifier);

        guardianConfigs[account].guardianCount++;
        guardianConfigs[account].totalWeight += weight;

        emit AddedGuardian(account, guardian, weight);
    }

    /**
     * @notice Removes a guardian for the caller's account
     * @dev This function can only be called by the account associated with the guardian and only if
     * no recovery is in process
     * @param guardian The identifier hash of the guardian to be removed
     */
    function removeGuardian(bytes32 guardian) external onlyWhenNotRecovering onlyWhenActive {
        GuardianConfig memory guardianConfig = guardianConfigs[msg.sender];
        GuardianStorage memory guardianStorage = guardiansStorage[msg.sender].get(guardian);

        bool success = guardiansStorage[msg.sender].remove(guardian);
        if (!success) {
            // false means that the guardian was not present in the map. This serves as a proxy that
            // the account is not authorized to remove this guardian
            revert AddressNotGuardianForAccount();
        }

        // Only allow guardian removal if threshold can still be reached.
        uint256 newTotalWeight = guardianConfig.totalWeight - guardianStorage.weight;
        if (newTotalWeight < guardianConfig.threshold) {
            revert ThresholdExceedsTotalWeight(newTotalWeight, guardianConfig.threshold);
        }

        removeAccountGuardianVerifier(guardian);

        guardianConfigs[msg.sender].guardianCount--;
        guardianConfigs[msg.sender].totalWeight -= guardianStorage.weight;
        if (guardianStorage.status == GuardianStatus.ACCEPTED) {
            guardianConfigs[msg.sender].acceptedWeight -= guardianStorage.weight;
        }

        emit RemovedGuardian(msg.sender, guardian, guardianStorage.weight);
    }

    /**
     * @notice Changes the threshold for guardian approvals for the caller's account
     * @dev This function can only be called by the account associated with the guardian config and
     * only if no recovery is in process
     * @param threshold The new threshold for guardian approvals
     */
    function changeThreshold(uint256 threshold) external onlyWhenNotRecovering onlyWhenActive {
        // Threshold can only be 0 at initialization.
        // Check ensures that setup function should be called first
        if (guardianConfigs[msg.sender].threshold == 0) {
            revert SetupNotCalled();
        }

        // Validate that threshold is smaller than the total weight.
        if (threshold > guardianConfigs[msg.sender].totalWeight) {
            revert ThresholdExceedsTotalWeight(threshold, guardianConfigs[msg.sender].totalWeight);
        }

        if (threshold == 0) {
            revert ThresholdCannotBeZero();
        }

        guardianConfigs[msg.sender].threshold = threshold;
        emit ChangedThreshold(msg.sender, threshold);
    }

    /**
     * @notice Updates the status for a guardian
     * @param account The address of the account associated with the guardian
     * @param guardian The identifier hash of the guardian
     * @param newStatus The new status for the guardian
     */
    function updateGuardianStatus(
        address account,
        bytes32 guardian,
        GuardianStatus newStatus
    )
        internal
    {
        GuardianStorage memory guardianStorage = guardiansStorage[account].get(guardian);
        if (newStatus == guardianStorage.status) {
            revert StatusCannotBeTheSame(newStatus);
        }

        guardiansStorage[account].set({
            key: guardian,
            value: GuardianStorage(newStatus, guardianStorage.weight)
        });
        emit GuardianStatusUpdated(account, guardian, newStatus);
    }

    /**
     * @notice Removes all guardians associated with an account
     * @dev Does not remove guardian config, this should be modified at the same time as calling
     * this function
     * @param account The address of the account associated with the guardians
     */
    function removeAllGuardians(address account) internal {
        bytes32[] memory guardians = guardiansStorage[account].keys();
        for(uint256 i = 0; i < guardians.length; i++) {
            removeAccountGuardianVerifier(guardians[i]);
        }
        guardiansStorage[account].removeAll(guardiansStorage[account].keys());
    }

    /**
     * @notice Gets all guardians associated with an account
     * @dev Return an array containing all the keys. O(n) where n <= 32
     *
     * WARNING: This operation will copy the entire storage to memory, which could
     * be quite expensive.
     * @param account The address of the account associated with the guardians
     */
    function getAllGuardians(address account) external view returns (bytes32[] memory) {
        return guardiansStorage[account].keys();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                GUARDIAN VERIFIER LOGIC                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Adds support for a guardian verifier for the caller's account
     * @param _guardianVerifier The address of the guardian verifier to be supported
     */
    function addSupportForGuardianVerifier(address _guardianVerifier) 
        public
        onlyWhenNotRecovering
        onlyWhenActive
    {
        address account = msg.sender;

        // require guardian verifier is not already supported for account
        if(isSupportedGuardianVerifier(account, _guardianVerifier)){
            revert GuardianVerifierAlreadySupported(account, _guardianVerifier);
        }
        isGuardianVerifier[account][_guardianVerifier] =  true;

        emit AddedSupportForGuardianVerifier(account, _guardianVerifier);
    }

    function setAccountGuardianVerifier(bytes memory guardian, address _guardianVerifier) external {
        setAccountGuardianVerifier(keccak256(guardian), _guardianVerifier);
    }

    /**
     * @notice Sets the guardian verifier for a guardian
     * @param guardian The identifier hash of the guardian
     * @param _guardianVerifier The address of the guardian verifier to be supported
     */
    function setAccountGuardianVerifier(bytes32 guardian, address _guardianVerifier) 
        public
        onlyWhenNotRecovering
        onlyWhenActive
    {
        address account = msg.sender;

        if(!isSupportedGuardianVerifier(account, _guardianVerifier)){
            revert GuardianVerifierNotSupported(account, _guardianVerifier);
        }
        address prevGuardianVerifier = getGuardianVerifier(account, guardian);
        if(prevGuardianVerifier != address(0) || prevGuardianVerifier == _guardianVerifier){
            revert GuardianVerifierAlreadySet(account, prevGuardianVerifier);
        }
        // require guardian verifier is not supported for guardian
        guardianVerifier[account][guardian] = _guardianVerifier;

        emit GuardianVerifierSet(account, guardian, _guardianVerifier);
    }

    function resetAccountGuardianVerifier(bytes memory guardian, address _newGuardianVerifier) external {
        resetAccountGuardianVerifier(keccak256(guardian), _newGuardianVerifier);
    }

    /**
     * @notice Resets the guardian verifier for a guardian
     * @param guardian The identifier hash of the guardian
     * @param _newGuardianVerifier The address of the new guardian verifier
     */
    function resetAccountGuardianVerifier(
        bytes32 guardian, 
        address _newGuardianVerifier
    ) 
        public
        onlyWhenNotRecovering
        onlyWhenActive
    {
        address account = msg.sender;
        if(!isSupportedGuardianVerifier(account, _newGuardianVerifier)){
            revert GuardianVerifierNotSupported(account, _newGuardianVerifier);
        }

        if(getGuardianVerifier(account, guardian) == address(0)){
            revert GuardianVerifierNotSet(account, guardian);
        }
        // require guardian verifier is supported for guardian
        guardianVerifier[account][guardian] = _newGuardianVerifier;

        emit GuardianVerifierReset(account, guardian, _newGuardianVerifier);
    }

    function removeAccountGuardianVerifier(bytes memory guardian) external {
        removeAccountGuardianVerifier(keccak256(guardian));
    }

    /**
     * @notice Removes the guardian verifier for a guardian
     * @param guardian The guardian to remove the verifier for.
     */
    function removeAccountGuardianVerifier(bytes32 guardian) 
        public
        onlyWhenNotRecovering
        onlyWhenActive
    {
        address account = msg.sender;
        if(getGuardianVerifier(account, guardian) == address(0)){
            revert GuardianVerifierNotSet(account, guardian);
        }
        guardianVerifier[account][guardian] = address(0);

        emit GuardianVerifierRemoved(account, guardian);
    }

    /**
     * @notice Retrieves the guardian verifier for a guardian
     * @param account The address of the account associated with the guardian
     * @param guardian The identifier hash of the guardian
     * @return address The address of the guardian verifier
     */
    function getGuardianVerifier(address account, bytes32 guardian) 
        public 
        view
        returns(address)
    {
        return guardianVerifier[account][guardian];
    }

    /**
     * @notice Checks if a guardian verifier is supported for an account
     * @param account The address of the account
     * @param _guardianVerifier The address of the guardian verifier
     * @return bool True if the guardian verifier is supported, false otherwise
     */
    function isSupportedGuardianVerifier(address account, address _guardianVerifier) 
        public 
        view
        returns(bool)
    {
        return isGuardianVerifier[account][_guardianVerifier];
    }
}
