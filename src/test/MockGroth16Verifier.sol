// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

struct EmailProof {
    string domainName; // Domain name of the sender's email
    bytes32 publicKeyHash; // Hash of the DKIM public key used in email/proof
    uint256 timestamp; // Timestamp of the email
    string maskedCommand; // Masked command of the email
    bytes32 emailNullifier; // Nullifier of the email to prevent its reuse.
    bytes32 accountSalt; // Create2 salt of the account
    bool isCodeExist; // Check if the account code is exist
    bytes proof; // ZK Proof of Email
}

/**
 * @notice Mock snarkjs Groth16 Solidity verifier
 */
contract MockGroth16Verifier {
    function verifyEmailProof(EmailProof memory proof) public pure returns (bool) {
        proof;

        return true;
    }
}
