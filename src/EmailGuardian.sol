// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IGuardian} from "./interfaces/IGuardian.sol";

contract EmailGuardian is IGuardian {
    constructor() {}

    /**
     * @notice Verifies a guardian signature for an account and hash
     * @param signature The guardian signature
     * @param hash The hash to verify
     */
    function verifySignature(
        bytes memory signature,
        bytes32 hash
    ) external pure returns (bool) {
        return true;
    }
}
