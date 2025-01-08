// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

struct EoaProof {
    bytes32 publicKeyHash; // Hash of the DKIM public key used in EOA/proof
    uint timestamp; // Timestamp of the email
    bytes32 eoaNullifier; // @dev - Nullifier of the EOA to prevent its reuse.
    bytes proof; // @dev - ZK Proof of EOA, which is specified as a "Guardian"
}

interface IVerifier {
    // function commandBytes() external view returns (uint256);

    function verifyEoaProof(
        EoaProof memory proof,
        uint256[34] calldata pubSignals
    ) external view returns (bool);
}