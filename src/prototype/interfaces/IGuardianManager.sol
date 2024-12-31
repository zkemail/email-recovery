// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { GuardianStorage, GuardianStatus } from "../libraries/EnumerableGuardianMap.sol";

interface IGuardianManager {
    /**
     * A struct representing the values required for guardian configuration
     * Config should be maintained over subsequent recovery attempts unless explicitly modified
     */
    struct GuardianConfig {
        uint256 guardianCount; // total count for all guardians
        uint256 totalWeight; // combined weight for all guardians. Important for checking that
            // thresholds are valid.
        uint256 acceptedWeight; // combined weight for all accepted guardians. This is separated
            // from totalWeight as it is important to prevent recovery starting without enough
            // accepted guardians to meet the threshold. Storing this in a variable avoids the need
            // to loop over accepted guardians whenever checking if a recovery attempt can be
            // started without being broken
        uint256 threshold; // the threshold required to successfully process a recovery attempt
    }

    event AddedGuardian(address indexed account, bytes32 indexed guardian, uint256 weight);
    event GuardianStatusUpdated(
        address indexed account, bytes32 indexed guardian, GuardianStatus newStatus
    );
    event RemovedGuardian(address indexed account, bytes32 indexed guardian, uint256 weight);
    event ChangedThreshold(address indexed account, uint256 threshold);

    event GuardianVerifierSet(address indexed account, bytes32 guardian, address indexed guardianVerifier);
    event GuardianVerifierReset(address indexed account, bytes32 guardian, address indexed guardianVerifier);
    event GuardianVerifierRemoved(address indexed account, bytes32 guardian);
    event AddedSupportForGuardianVerifier(address indexed account, address indexed guardianVerifier);

    error RecoveryInProcess();
    error KillSwitchEnabled();
    error IncorrectNumberOfWeights(uint256 guardianCount, uint256 weightCount);
    error ThresholdCannotBeZero();
    error InvalidGuardianAddress(bytes32 guardian);
    error InvalidGuardianWeight();
    error AddressAlreadyGuardian();
    error ThresholdExceedsTotalWeight(uint256 threshold, uint256 totalWeight);
    error StatusCannotBeTheSame(GuardianStatus newStatus);
    error SetupNotCalled();
    error AddressNotGuardianForAccount();
    error IncorrectNumberOfGuardianVerifiers(uint256 guardianCount, uint256 verifierCount);

    error GuardianVerifierAlreadySupported(address account, address guardianVerifier);
    error GuardianVerifierNotSupported(address account, address guardianVerifier);
    error GuardianVerifierAlreadySet(address account, address guardianVerifier);
    error GuardianVerifierNotSet(address account, bytes32 guardian);
    error GuardianNotCaller(address msgSender, address guardian);

    function getGuardianConfig(address account) external view returns (GuardianConfig memory);

    function getGuardian(
        address account,
        bytes32 guardian
    )
        external
        view
        returns (GuardianStorage memory);

    function addGuardian(bytes32 guardian, address guardianVerifier, uint256 weight) external;

    function removeGuardian(bytes32 guardian) external;

    function changeThreshold(uint256 threshold) external;

    function getAllGuardians(address account) external returns (bytes32[] memory);

    function setAccountGuardianVerifier(bytes memory guardian, address _guardianVerifier) 
        external;
    
    function resetAccountGuardianVerifier(
        bytes32 guardian, 
        address _newGuardianVerifier
    ) external;

    function removeAccountGuardianVerifier(bytes32 guardian) external ;

}
