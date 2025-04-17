// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IGuardian {
    function verifySignature(
        bytes memory signature,
        bytes32 hash
    ) external returns (bool);
}
