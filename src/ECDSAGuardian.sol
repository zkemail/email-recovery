// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SignerECDSA} from "@openzeppelin/community-contracts/contracts/utils/cryptography/SignerECDSA.sol";
import {IGuardian} from "./interfaces/IGuardian.sol";

contract ECDSAGuardian is IGuardian, SignerECDSA, Initializable {
    constructor() {
        _disableInitializers();
    }

    function initialize(address signerAddr) public initializer {
        _setSigner(signerAddr);
    }

    /**
     * @notice Verifies a guardian signature for a signer and hash
     * @param signature The guardian signature
     * @param hash The hash to verify
     */
    function verifySignature(
        bytes calldata signature,
        bytes32 hash
    ) external view returns (bool) {
        return _rawSignatureValidation(hash, signature);
    }
}
