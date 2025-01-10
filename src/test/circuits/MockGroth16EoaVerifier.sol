// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.25;

import {
    IVerifier,
    EoaProof
} from "../../eoa-auth/interfaces/circuits/IVerifier.sol";

/**
 * @notice Mock snarkjs Groth16 EOA Solidity verifier
 */
contract MockGroth16EoaVerifier is IVerifier {
    function verifyEoaProof(
        EoaProof memory proof,
        uint256[34] calldata pubSignals
    ) public view returns (bool) {
        proof;

        return true;
    }
}
