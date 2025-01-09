// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {
    IVerifier,
    EoaProof
} from "../../interfaces/circuits/IVerifier.sol";

/**
 * @notice Mock snarkjs Groth16 EOA Solidity verifier
 */
contract MockGroth16EoaVerifier is IVerifier {
    function verifyEoaProof(EoaProof memory proof) public pure returns (bool) {
        proof;

        return true;
    }
}
