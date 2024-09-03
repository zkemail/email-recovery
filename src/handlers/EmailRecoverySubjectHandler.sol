// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IEmailRecoverySubjectHandler } from "../interfaces/IEmailRecoverySubjectHandler.sol";
import { StringUtils } from "../libraries/StringUtils.sol";

/**
 * @title EmailRecoverySubjectHandler
 * @notice Handler contract that defines subject templates and how to validate them
 * This is the default subject handler that will work with any validator.
 */
contract EmailRecoverySubjectHandler is IEmailRecoverySubjectHandler {
    error InvalidTemplateIndex(uint256 templateIdx, uint256 expectedTemplateIdx);
    error InvalidSubjectParams(uint256 paramsLength, uint256 expectedParamsLength);
    error InvalidAccount();

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
        templates[0][4] = "{ethAddr}";
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
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "using";
        templates[0][4] = "recovery";
        templates[0][5] = "hash";
        templates[0][6] = "{string}";
        return templates;
    }

    /**
     * @notice Extracts the account address to be recovered from the subject parameters of an
     * acceptance email.
     * @param subjectParams The subject parameters of the acceptance email.
     * @param {templateIdx} Unused parameter. The index of the template used for acceptance
     */
    function extractRecoveredAccountFromAcceptanceSubject(
        bytes[] calldata subjectParams,
        uint256 /* templateIdx */
    )
        public
        pure
        returns (address)
    {
        return abi.decode(subjectParams[0], (address));
    }

    /**
     * @notice Extracts the account address to be recovered from the subject parameters of a
     * recovery email.
     * @param subjectParams The subject parameters of the recovery email.
     * @param {templateIdx} Unused parameter. The index of the template used for the recovery
     * request
     */
    function extractRecoveredAccountFromRecoverySubject(
        bytes[] calldata subjectParams,
        uint256 /* templateIdx */
    )
        public
        pure
        returns (address)
    {
        return abi.decode(subjectParams[0], (address));
    }

    /**
     * @notice Validates the subject params for an acceptance email
     * @param templateIdx The index of the template used for acceptance
     * @param subjectParams The subject parameters of the acceptance email.
     * @return accountInEmail The account address in the acceptance email
     */
    function validateAcceptanceSubject(
        uint256 templateIdx,
        bytes[] calldata subjectParams
    )
        external
        pure
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
        address accountInEmail = abi.decode(subjectParams[0], (address));

        return accountInEmail;
    }

    /**
     * @notice Validates the subject params for an acceptance email
     * @param templateIdx The index of the template used for the recovery request
     * @param subjectParams The subject parameters of the recovery email
     * @return accountInEmail The account address in the recovery email
     */
    function validateRecoverySubject(
        uint256 templateIdx,
        bytes[] calldata subjectParams
    )
        public
        pure
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        if (subjectParams.length != 2) {
            revert InvalidSubjectParams(subjectParams.length, 2);
        }

        address accountInEmail = abi.decode(subjectParams[0], (address));
        string memory recoveryDataHashInEmail = abi.decode(subjectParams[1], (string));

        if (accountInEmail == address(0)) {
            revert InvalidAccount();
        }
        // hexToBytes32 validates the recoveryDataHash is not zero bytes and has the correct length
        StringUtils.hexToBytes32(recoveryDataHashInEmail);

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
        return StringUtils.hexToBytes32(abi.decode(subjectParams[1], (string)));
    }
}
