// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IVerifier} from "../interfaces/IHonkVerifier.sol";

contract MockHonkVerifier is IVerifier {
    function verify(
        bytes calldata _proof,
        bytes32[] calldata _publicInputs
    ) external view override returns (bool) {
        return true;
    }
}
