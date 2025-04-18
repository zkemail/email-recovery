// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {SignerZKEmail} from "@openzeppelin/community-contracts/contracts/utils/cryptography/SignerZKEmail.sol";
import {IDKIMRegistry} from "@zk-email/contracts/DKIMRegistry.sol";
import {IVerifier} from "@zk-email/email-tx-builder/interfaces/IVerifier.sol";
import {IGuardian} from "./interfaces/IGuardian.sol";

contract EmailGuardian is IGuardian, SignerZKEmail, Initializable {
    constructor() {
        _disableInitializers();
    }

    function initialize(
        bytes32 accountSalt,
        IDKIMRegistry registry,
        IVerifier verifier,
        uint256 templateId
    ) public initializer {
        _setAccountSalt(accountSalt);
        _setDKIMRegistry(registry);
        _setVerifier(verifier);
        _setTemplateId(templateId);
    }

    /**
     * @notice Verifies a guardian signature for an email and a hash
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
