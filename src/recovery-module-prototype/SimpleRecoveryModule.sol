// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

// Core interfaces
interface IERC7579Account {
    function changeOwner(address newOwner) external;
}

struct EmailProof {
    string domainName;
    bytes32 publicKeyHash;
    uint timestamp;
    string maskedCommand;
    bytes32 emailNullifier;
    bytes32 accountSalt;
    bool isCodeExist;
    bytes proof;
}

interface IVerifier {
    function commandBytes() external view returns (uint256);
    function verifyEmailProof(EmailProof memory proof) external view returns (bool);
}

interface IDKIMRegistry {
    function isDKIMPublicKeyHashValid(
        string memory domainName,
        bytes32 publicKeyHash
    ) external view returns (bool);
}

/**
 * @title SimpleRecoveryModule
 * @notice A simplified recovery module supporting both ZK Email and EOA guardians
 */
contract SimpleRecoveryModule {
    // State variables
    mapping(address => address) public accountOwners;
    mapping(address => address) public accountGuardians;
    mapping(address => bytes32) public accountNullifiers;
    
    IVerifier public immutable zkEmailVerifier;
    IDKIMRegistry public immutable dkimRegistry;
    
    // Events
    event RecoveryInitiated(address indexed account, address newOwner);
    event GuardianSet(address indexed account, address guardian);
    event NullifierUsed(bytes32 indexed nullifier, address indexed account);
    
    error InvalidGuardian();
    error InvalidProof();
    error InvalidDKIM();
    error NullifierAlreadyUsed();
    error InvalidNewOwner();
    
    constructor(address _verifier, address _dkimRegistry) {
        zkEmailVerifier = IVerifier(_verifier);
        dkimRegistry = IDKIMRegistry(_dkimRegistry);
    }
    
    /**
     * @notice Set up EOA guardian for an account
     * @param guardian EOA guardian address
     */
    function setupGuardian(address guardian) external {
        if (guardian == address(0)) revert InvalidGuardian();
        accountGuardians[msg.sender] = guardian;
        accountOwners[msg.sender] = msg.sender;
        
        emit GuardianSet(msg.sender, guardian);
    }
    
    /**
     * @notice Recover account using EOA guardian
     * @param account Account to recover
     * @param newOwner New owner address
     */
    function recoverByGuardian(address account, address newOwner) external {
        if (msg.sender != accountGuardians[account]) revert InvalidGuardian();
        if (newOwner == address(0)) revert InvalidNewOwner();
        
        _executeRecovery(account, newOwner);
    }
    
    /**
     * @notice Recover account using ZK Email proof
     * @param account Account to recover
     * @param newOwner New owner address
     * @param emailProof Email proof data
     */
    function recoverByEmail(
        address account,
        address newOwner,
        EmailProof calldata emailProof
    ) external {
        if (newOwner == address(0)) revert InvalidNewOwner();
        
        // Verify DKIM
        if (!dkimRegistry.isDKIMPublicKeyHashValid(
            emailProof.domainName,
            emailProof.publicKeyHash
        )) revert InvalidDKIM();
        
        // Check nullifier hasn't been used
        if (accountNullifiers[account] == emailProof.emailNullifier) revert NullifierAlreadyUsed();
        
        // Verify ZK proof
        if (!zkEmailVerifier.verifyEmailProof(emailProof)) revert InvalidProof();
        
        // Store nullifier
        accountNullifiers[account] = emailProof.emailNullifier;
        emit NullifierUsed(emailProof.emailNullifier, account);
        
        _executeRecovery(account, newOwner);
    }
    
    /**
     * @notice Internal function to execute recovery
     */
    function _executeRecovery(address account, address newOwner) internal {
        IERC7579Account(account).changeOwner(newOwner);
        accountOwners[account] = newOwner;
        
        emit RecoveryInitiated(account, newOwner);
    }
}