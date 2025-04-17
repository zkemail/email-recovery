// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {ECDSAGuardian} from "./ECDSAGuardian.sol";

/**
 * @title ECDSAGuardianFactory
 * @notice Factory contract for creating ECDSAGuardian instances using the minimal proxy pattern, or "clones"
 */
contract ECDSAGuardianFactory {
    using Clones for address;

    address private immutable implementation = address(new ECDSAGuardian());

    function predictAddress(bytes32 salt) public view returns (address) {
        return implementation.predictDeterministicAddress(salt, address(this));
    }

    function cloneAndInitialize(
        bytes32 salt,
        address signer
    ) public returns (address) {
        // Scope salt to the signer to avoid front-running the salt with a different signer
        bytes32 _signerSalt = keccak256(abi.encodePacked(salt, signer));

        address predicted = predictAddress(_signerSalt);
        if (predicted.code.length == 0) {
            implementation.cloneDeterministic(_signerSalt);
            ECDSAGuardian(payable(predicted)).initialize(signer);
        }
        return predicted;
    }
}
