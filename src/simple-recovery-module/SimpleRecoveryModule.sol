// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {
    IVerifier,
    EmailProof
} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

interface IERC7579Account {
    function changeOwner(address newOwner) external;
}

interface IDKIMRegistry {
    function isDKIMPublicKeyHashValid(
        string memory domainName,
        bytes32 publicKeyHash
    )
        external
        view
        returns (bool);
}

/**
 * @title SimpleRecoveryModule
 * @notice A simple recovery module that supports both ZK Email & EOA guardians
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
    event InvalidProofAttempt(
        address indexed account, uint256 proofTimestamp, uint256 currentTimestamp, string reason
    );

    // Errors
    error SimpleRecoveryModule__InvalidGuardian();
    error SimpleRecoveryModule__InvalidProof();
    error SimpleRecoveryModule__InvalidDKIM();
    error SimpleRecoveryModule__NullifierIsUsed();
    error SimpleRecoveryModule__InvalidNewOwner();
    error SimpleRecoveryModule__GuardianAlreadySet();

    constructor(address _verifier, address _dkimRegistry) {
        require(_verifier != address(0), "Invalid verifier address");
        require(_dkimRegistry != address(0), "Invalid DKIM registry address");
        zkEmailVerifier = IVerifier(_verifier);
        dkimRegistry = IDKIMRegistry(_dkimRegistry);
    }

    /**
     * @notice Set up EOA guardian for account
     * @param guardian EOA guardian address
     */
    function setupGuardian(address guardian) external {
        if (guardian == address(0)) revert SimpleRecoveryModule__InvalidGuardian();
        if (accountGuardians[msg.sender] != address(0)) {
            revert SimpleRecoveryModule__GuardianAlreadySet();
        }
        accountGuardians[msg.sender] = guardian;
        accountOwners[msg.sender] = msg.sender;

        emit GuardianSet(msg.sender, guardian);
    }

    /**
     * @notice Recover account using an EOA guardian
     * @param account Account to be recovered
     * @param newOwner New owner address
     */
    function recoverByGuardian(address account, address newOwner) external {
        if (msg.sender != accountGuardians[account]) revert SimpleRecoveryModule__InvalidGuardian();
        if (newOwner == address(0)) revert SimpleRecoveryModule__InvalidNewOwner();

        _executeRecovery(account, newOwner);
    }

    /**
     * @notice Recover account using ZK Email proof
     * @param account Account to be recovered
     * @param newOwner New owner address
     * @param emailProof Email proof data
     */
    function recoverByEmail(
        address account,
        address newOwner,
        EmailProof calldata emailProof
    )
        external
    {
        if (newOwner == address(0)) revert SimpleRecoveryModule__InvalidNewOwner();

        // Verify DKIM
        if (!dkimRegistry.isDKIMPublicKeyHashValid(emailProof.domainName, emailProof.publicKeyHash))
        {
            revert SimpleRecoveryModule__InvalidDKIM();
        }

        // Prevent replay attacks by verifying nullifier hasn't been used
        if (accountNullifiers[account] == emailProof.emailNullifier) {
            emit InvalidProofAttempt(
                account, emailProof.timestamp, block.timestamp, "Nullifier already used"
            );
            revert SimpleRecoveryModule__NullifierIsUsed();
        }

        // Verify proof
        if (!zkEmailVerifier.verifyEmailProof(emailProof)) {
            revert SimpleRecoveryModule__InvalidProof();
        }

        // Prevent replay attacks with outdated proofs
        if (emailProof.timestamp < block.timestamp - 1 hours) {
            emit InvalidProofAttempt(
                account, emailProof.timestamp, block.timestamp, "Proof expired"
            );
            revert SimpleRecoveryModule__InvalidProof();
        }

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
