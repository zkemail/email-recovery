// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IEmailRecoveryCommandHandler } from "../interfaces/IEmailRecoveryCommandHandler.sol";
import { StringUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/StringUtils.sol";

/**
 * @title AccountHidingRecoveryCommandHandler
 * @notice Handler contract that defines command templates and how to validate them
 * This command handler does not expose the account address in the email command
 */
contract AccountHidingRecoveryCommandHandler is IEmailRecoveryCommandHandler {
    error InvalidTemplateIndex(uint256 templateIdx, uint256 expectedTemplateIdx);
    error InvalidCommandParams(uint256 paramsLength, uint256 expectedParamsLength);
    error InvalidAccount();
    error ExistingStoredAccountHash(address account);

    // Mapping of account hashes to their addresses
    mapping(bytes32 accountHash => address account) public accountHashes;

    /**
     * @notice Returns a hard-coded two-dimensional array of strings representing the command
     * templates for an acceptance by a new guardian.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function acceptanceCommandTemplates() public pure returns (string[][] memory) {
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
     * @notice Returns a hard-coded two-dimensional array of strings representing the command
     * templates for email recovery.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function recoveryCommandTemplates() public pure returns (string[][] memory) {
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
     * @notice Extracts the hash of the account address to be recovered from the command parameters
     * of the acceptance email and returns the corresponding address stored in accountHashes.
     * @param commandParams The command parameters of the acceptance email.
     * @param {templateIdx} Unused parameter. The index of the template used for acceptance
     */
    function extractRecoveredAccountFromAcceptanceCommand(
        bytes[] calldata commandParams,
        uint256 /* templateIdx */
    )
        public
        view
        returns (address)
    {
        bytes32 accountHash = StringUtils.hexToBytes32(abi.decode(commandParams[0], (string)));
        return accountHashes[accountHash];
    }

    /**
     * @notice Extracts the hash of the account address to be recovered from the command parameters
     * of the recovery email and returns the corresponding address stored in accountHashes.
     * @param commandParams The command parameters of the recovery email.
     * @param {templateIdx} Unused parameter. The index of the template used for the recovery
     * request
     */
    function extractRecoveredAccountFromRecoveryCommand(
        bytes[] calldata commandParams,
        uint256 /* templateIdx */
    )
        public
        view
        returns (address)
    {
        bytes32 accountHash = StringUtils.hexToBytes32(abi.decode(commandParams[0], (string)));
        return accountHashes[accountHash];
    }

    /**
     * @notice Validates the command params for an acceptance email
     * @param templateIdx The index of the template used for acceptance
     * @param commandParams The command parameters of the acceptance email.
     * @return accountInEmail The account address in the acceptance email
     */
    function validateAcceptanceCommand(
        uint256 templateIdx,
        bytes[] calldata commandParams
    )
        external
        view
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        if (commandParams.length != 1) {
            revert InvalidCommandParams(commandParams.length, 1);
        }

        // The GuardianStatus check in acceptGuardian implicitly
        // validates the account, so no need to re-validate here
        address accountInEmail =
            extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);

        return accountInEmail;
    }

    /**
     * @notice Validates the command params for an acceptance email
     * @param templateIdx The index of the template used for the recovery request
     * @param commandParams The command parameters of the recovery email
     * @return accountInEmail The account address in the recovery email
     */
    function validateRecoveryCommand(
        uint256 templateIdx,
        bytes[] calldata commandParams
    )
        public
        view
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        if (commandParams.length != 2) {
            revert InvalidCommandParams(commandParams.length, 2);
        }

        address accountInEmail =
            extractRecoveredAccountFromRecoveryCommand(commandParams, templateIdx);
        string memory recoveryDataHashInEmail = abi.decode(commandParams[1], (string));

        if (accountInEmail == address(0)) {
            revert InvalidAccount();
        }
        // hexToBytes32 validates the recoveryDataHash is not zero bytes and has the correct length
        StringUtils.hexToBytes32(recoveryDataHashInEmail);

        return accountInEmail;
    }

    /**
     * @notice Parses the recovery data hash from the command params. The data hash is
     * verified against later when recovery is executed
     * @dev recoveryDataHash = keccak256(abi.encode(validatorOrAccount, recoveryFunctionCalldata))
     * @param templateIdx The index of the template used for the recovery request
     * @param commandParams The command parameters of the recovery email
     * @return recoveryDataHash The keccak256 hash of the recovery data
     */
    function parseRecoveryDataHash(
        uint256 templateIdx,
        bytes[] calldata commandParams
    )
        external
        pure
        returns (bytes32)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        return StringUtils.hexToBytes32(abi.decode(commandParams[1], (string)));
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
