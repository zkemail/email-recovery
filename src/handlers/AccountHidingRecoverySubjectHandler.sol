// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IEmailRecoverySubjectHandler } from "../interfaces/IEmailRecoverySubjectHandler.sol";
import { StringUtils } from "../libraries/StringUtils.sol";

/**
 * Handler contract that defines subject templates and how to validate them
 * This is the subject handler that does not expose the account address in the email subject
 */
contract AccountHidingRecoverySubjectHandler is IEmailRecoverySubjectHandler {
    error InvalidTemplateIndex(uint256 templateIdx, uint256 expectedTemplateIdx);
    error InvalidSubjectParams(uint256 paramsLength, uint256 expectedParamsLength);
    error InvalidAccount();
    error ExistingStoredAccountHash(address account);

    // Mapping of account hashes to their addresses
    mapping(bytes32 accountHash => address account) public accountHashes;

    /**
     * @notice Returns a hard-coded two-dimensional array of strings representing the subject
     * templates for an acceptance by a new guardian.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a subject template.
     */
    function acceptanceSubjectTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](5);
        templates[0][0] = "Accept";
        templates[0][1] = "guardian";
        templates[0][2] = "request";
        templates[0][3] = "for";
        templates[0][4] = "{string}";
        return templates;
    }

    /**
     * @notice Returns a hard-coded two-dimensional array of strings representing the subject
     * templates for email recovery.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a subject template.
     */
    function recoverySubjectTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](7);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{string}";
        templates[0][3] = "using";
        templates[0][4] = "recovery";
        templates[0][5] = "hash";
        templates[0][6] = "{string}";
        return templates;
    }

    /**
     * @notice Extracts the hash of the account address to be recovered from the subject parameters
     * of acceptance email and returns the corresponding address stored in the accountHashes.
     * @param subjectParams The subject parameters of the acceptance email.
     */
    function extractRecoveredAccountFromAcceptanceSubject(
        bytes[] calldata subjectParams,
        uint256 /* templateIdx */
    )
        public
        view
        returns (address)
    {
        bytes32 accountHash = StringUtils.hexToBytes32(abi.decode(subjectParams[0], (string)));
        return accountHashes[accountHash];
    }

    /**
     * @notice Extracts the hash of the account address to be recovered from the subject parameters
     * of recovery email and returns the corresponding address stored in the accountHashes.
     * @param subjectParams The subject parameters of the recovery email.
     */
    function extractRecoveredAccountFromRecoverySubject(
        bytes[] calldata subjectParams,
        uint256 /* templateIdx */
    )
        public
        view
        returns (address)
    {
        bytes32 accountHash = StringUtils.hexToBytes32(abi.decode(subjectParams[0], (string)));
        return accountHashes[accountHash];
    }

    /**
     * @notice Validates the subject params for an acceptance email
     * @param templateIdx The index of the template used for acceptance
     * @param subjectParams The subject parameters of the recovery email.
     * @return accountInEmail The account address in the acceptance email
     */
    function validateAcceptanceSubject(
        uint256 templateIdx,
        bytes[] calldata subjectParams
    )
        external
        view
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        if (subjectParams.length != 1) {
            revert InvalidSubjectParams(subjectParams.length, 1);
        }

        // The GuardianStatus check in acceptGuardian implicitly
        // validates the account, so no need to re-validate here
        address accountInEmail =
            extractRecoveredAccountFromAcceptanceSubject(subjectParams, templateIdx);

        return accountInEmail;
    }

    /**
     * @notice Validates the subject params for an acceptance email
     * @param templateIdx The index of the template used for the recovery request
     * @param subjectParams The subject parameters of the recovery email
     * @return accountInEmail The account address in the acceptance email
     */
    function validateRecoverySubject(
        uint256 templateIdx,
        bytes[] calldata subjectParams
    )
        public
        view
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        if (subjectParams.length != 2) {
            revert InvalidSubjectParams(subjectParams.length, 2);
        }

        address accountInEmail =
            extractRecoveredAccountFromRecoverySubject(subjectParams, templateIdx);
        string memory recoveryDataHashInEmail = abi.decode(subjectParams[1], (string));
        // hexToBytes32 validates the recoveryDataHash is not zero bytes and has the correct length
        StringUtils.hexToBytes32(recoveryDataHashInEmail);

        if (accountInEmail == address(0)) {
            revert InvalidAccount();
        }

        return accountInEmail;
    }

    /**
     * @notice parses the recovery data hash from the subject params. The data hash is
     * verified against later when recovery is executed
     * @dev recoveryDataHash = abi.encode(validator, recoveryFunctionCalldata)
     * @param templateIdx The index of the template used for the recovery request
     * @param subjectParams The subject parameters of the recovery email
     * @return recoveryDataHash The keccak256 hash of the recovery data
     */
    function parseRecoveryDataHash(
        uint256 templateIdx,
        bytes[] calldata subjectParams
    )
        external
        pure
        returns (bytes32)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }

        string memory recoveryDataHashInEmail = abi.decode(subjectParams[1], (string));
        return StringUtils.hexToBytes32(recoveryDataHashInEmail);
    }

    /**
     * @notice Stores the account hash in the accountHashes mapping
     * @param account The account address to store
     */
    function storeAccountHash(address account) public {
        bytes32 accountHash = keccak256(abi.encodePacked(account));
        if (accountHashes[accountHash] != address(0)) {
            revert ExistingStoredAccountHash(account);
        }
        accountHashes[accountHash] = account;
    }
}
