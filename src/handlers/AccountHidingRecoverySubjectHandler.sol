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
    error InvalidRecoveryModule(address recoveryModule);
    error ExistingStoredAccountHash(address account);

    // Mapping of account hashes to their addresses
    mapping(bytes32=>address) public accountHashes;

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
        templates[0] = new string[](11);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{string}";
        templates[0][3] = "via";
        templates[0][4] = "recovery";
        templates[0][5] = "module";
        templates[0][6] = "{ethAddr}";
        templates[0][7] = "using";
        templates[0][8] = "recovery";
        templates[0][9] = "hash";
        templates[0][10] = "{string}";
        return templates;
    }

    /**
     * @notice Extracts the hash of the account address to be recovered from the subject parameters of
     * acceptance email and returns the corresponding address stored in the accountHashes.
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
     * @notice Extracts the hash of the account address to be recovered from the subject parameters of
     * recovery email and returns the corresponding address stored in the accountHashes.
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
        address accountInEmail = extractRecoveredAccountFromAcceptanceSubject(subjectParams, templateIdx);

        return accountInEmail;
    }

    /**
     * @notice Validates the subject params for an acceptance email
     * @param templateIdx The index of the template used for the recovery request
     * @param subjectParams The subject parameters of the recovery email
     * @param expectedRecoveryModule The recovery module address. Used to help with validation
     * @return accountInEmail The account address in the acceptance email
     */
    function validateRecoverySubject(
        uint256 templateIdx,
        bytes[] calldata subjectParams,
        address expectedRecoveryModule
    )
        public
        view
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        if (subjectParams.length != 3) {
            revert InvalidSubjectParams(subjectParams.length, 3);
        }

        address accountInEmail = extractRecoveredAccountFromRecoverySubject(subjectParams, templateIdx);
        address recoveryModuleInEmail = abi.decode(subjectParams[1], (address));
        string memory calldataHashInEmail = abi.decode(subjectParams[2], (string));
        // hexToBytes32 validates the calldataHash is not zero bytes and has the correct length
        StringUtils.hexToBytes32(calldataHashInEmail);

        if (accountInEmail == address(0)) {
            revert InvalidAccount();
        }

        // Even though someone could use a malicious contract as the expectedRecoveryModule
        // argument, it does not matter in this case as this is only used as part of the recovery
        // flow in the recovery module. Passing the recovery module in the constructor here would
        // result in a circular dependency
        if (recoveryModuleInEmail == address(0) || recoveryModuleInEmail != expectedRecoveryModule)
        {
            revert InvalidRecoveryModule(recoveryModuleInEmail);
        }

        return accountInEmail;
    }

    /**
     * @notice parses the recovery calldata hash from the subject params. The calldata hash is
     * verified against later when recovery is executed
     * @param templateIdx The index of the template used for the recovery request
     * @param subjectParams The subject parameters of the recovery email
     * @return calldataHash The keccak256 hash of the recovery calldata
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

        string memory calldataHashInEmail = abi.decode(subjectParams[2], (string));
        return StringUtils.hexToBytes32(calldataHashInEmail);
    }

    /**
     * @notice Stores the account hash in the accountHashes mapping
     * @param account The account address to store
     */
    function storeAccountHash(address account) public {
        bytes32 accountHash = keccak256(abi.encodePacked(account));
        if(accountHashes[accountHash] != address(0)) {
            revert ExistingStoredAccountHash(account);
        }
        accountHashes[accountHash] = account;
    }
}
