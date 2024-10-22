// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {
    IVerifier,
    EmailProof
} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

/**
 * @notice Mock snarkjs Groth16 Solidity verifier
 */
contract MockGroth16Verifier is IVerifier {
    uint256 public constant DOMAIN_FIELDS = 9;
    uint256 public constant DOMAIN_BYTES = 255;
    uint256 public constant COMMAND_FIELDS = 20;
    uint256 public constant COMMAND_BYTES = 605;

    function commandBytes() external pure returns (uint256) {
        return COMMAND_BYTES;
    }

    function verifyEmailProof(EmailProof memory proof) public pure returns (bool) {
        proof;

        return true;
    }
}
