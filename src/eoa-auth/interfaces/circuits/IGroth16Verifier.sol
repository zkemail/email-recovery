// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IGroth16Verifier {
    function verifyProof(
        uint[2] calldata _pA,
        uint[2][2] calldata _pB,
        uint[2] calldata _pC,
        uint[34] calldata _pubSignals
    ) external view returns (bool);
}
