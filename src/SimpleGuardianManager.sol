// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

contract SimpleGuardianManager {
    struct GuardianConfig {
        address[] guardians;
        mapping(address => uint256) weights;
        uint256 threshold;
    }

    struct RecoverySession {
        address[] proofSubmitters;
        bytes[] proofs;
        uint256 timestamp;
        bool active;
    }

    mapping(address => GuardianConfig) public guardianConfigs;
    mapping(address => mapping(uint256 => RecoverySession)) private recoverySessions;

    uint256 public constant PROOF_VALIDITY_PERIOD = 3 days;

    event GuardiansUpdated(address indexed account, address[] guardians, uint256 threshold);
    event GuardianWeightUpdated(address indexed account, address guardian, uint256 weight);
    event GuardiansDeleted(address indexed account);
    event RecoveryInitiated(address indexed account, uint256 timestamp);
    event ProofSubmitted(address indexed account, address indexed guardian, uint256 timestamp);

    modifier onlyValidThreshold(uint256 threshold) {
        require(threshold > 0 , "Invalid threshold");
        _;
    }

    modifier onlyGuardian(address account) {
        bool isGuardian = false;
        for (uint256 i = 0; i < guardianConfigs[account].guardians.length; i++) {
            if (guardianConfigs[account].guardians[i] == msg.sender) {
                isGuardian = true;
                break;
            }
        }

        require(isGuardian, "Not a guardian");
        _;
    }

    function setGuardians(address account, address[] calldata guardians, uint256 threshold) 
        external 
        onlyValidThreshold(threshold) 
    {
        require(guardians.length > 0, "Guardians required");
        
        GuardianConfig storage config = guardianConfigs[account];
        
        delete config.guardians;
        for (uint256 i = 0; i < guardians.length; i++) {
            config.guardians.push(guardians[i]);
            config.weights[guardians[i]] = 1;
        }
        config.threshold = threshold;

        emit GuardiansUpdated(account, guardians, threshold);
    }

    function updateGuardianWeight(address account, address guardian, uint256 weight) external {
        require(guardianConfigs[account].weights[guardian] != 0, "Guardian not found");
        require(weight > 0, "Weight must be greater than zero");
        
        guardianConfigs[account].weights[guardian] = weight;

        emit GuardianWeightUpdated(account, guardian, weight);
    }

    function deleteGuardians(address account) external {
        delete guardianConfigs[account];
        emit GuardiansDeleted(account);
    }

    function initiateRecovery(address account) external returns (uint256) {
        uint256 timestamp = block.timestamp;
        RecoverySession storage session = recoverySessions[account][timestamp];
        session.timestamp = timestamp;
        session.active = true;
        emit RecoveryInitiated(account, timestamp);
        return timestamp;
    }

    function submitProof(address account, uint256 timestamp, bytes calldata proof) external onlyGuardian(account) {
        require(recoverySessions[account][timestamp].active, "No active recovery session");
        require(block.timestamp <= timestamp + PROOF_VALIDITY_PERIOD, "Proof expired");
        
        recoverySessions[account][timestamp].proofSubmitters.push(msg.sender);
        recoverySessions[account][timestamp].proofs.push(proof);
        
        emit ProofSubmitted(account, msg.sender, timestamp);
    }

    function hasThresholdBeenMet(address account, uint256 timestamp) external view returns (bool) {
        return recoverySessions[account][timestamp].proofSubmitters.length >= guardianConfigs[account].threshold;
    }

    function getGuardians(address account) external view returns (address[] memory, uint256) {
        GuardianConfig storage config = guardianConfigs[account];
        return (config.guardians, config.threshold);
    }

    function getGuardianWeight(address account, address guardian) external view returns (uint256) {
        return guardianConfigs[account].weights[guardian];
    }

    function getSubmittedProofs(address account, uint256 timestamp) 
    external view returns (address[] memory, bytes[] memory) {
        RecoverySession storage session = recoverySessions[account][timestamp];
        return (session.proofSubmitters, session.proofs);
    }

    function setRecoveryCompleted(address account, uint256 timestamp) external onlyGuardian(account) {
        require(recoverySessions[account][timestamp].active, "No active recovery session");
        recoverySessions[account][timestamp].active = false;
    }
}