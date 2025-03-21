// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDKIMRegistry} from "@zk-email/contracts/DKIMRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IGuardianVerifier} from "./interfaces/IGuardianVerifier.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IEmailRecoveryCommandHandler} from "./interfaces/IEmailRecoveryCommandHandler.sol";
import {EmailAuthMsg} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import {CommandUtils} from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import {IVerifier, EmailProof} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

/**
 * @title EmailGuardianVerifier
 * @notice Provides a mechanism for guardian verification using email-based proofs.
 * @dev The underlying IGuardianVerifier provides the interface for proof verification.
 */
contract EmailGuardianVerifier is IGuardianVerifier, Initializable {
    // NOTE: Temporary bypass, remove after the upgrade
    address _owner;

    // TODO: Check if it's required
    uint8 public constant EMAIL_GUARDIAN_VERIFIER_VERSION_ID = 1;

    address public commandHandler;

    bool public timestampCheckEnabled;
    uint256 public lastTimestamp;

    mapping(uint256 templateId => string[] template) public commandTemplates;
    mapping(bytes32 emailNullifier => bool used) public usedNullifiers;

    IDKIMRegistry public dkimRegistry;
    // TODO: Can we abstracted the main verifier Library as well ?
    IVerifier public verifier;

    struct EmailData {
        uint256 templateIdx;
        bytes[] commandParams;
        uint256 skippedCommandPrefix;
        string domainName;
        uint256 timestamp;
        string maskedCommand;
        bytes32 accountSalt;
        bool isCodeExist;
        bool isRecovery;
    }

    /// @notice Returns the address of the DKIM registry contract.
    /// @return address The address of the DKIM registry contract.
    function dkimRegistryAddr() public view returns (address) {
        return address(dkimRegistry);
    }

    /// @notice Returns the address of the verifier contract.
    /// @return address The Address of the verifier contract.
    function verifierAddr() public view returns (address) {
        return address(verifier);
    }

    constructor() {}

    //TODO: Maybe accountSalt can be passed while intializing the contract
    /**
     * @dev Initializes the contract with the DKIM registry, verifier, and command handler addresses.
     * @notice Addresses are hardcoded for the initial implementation.
     *
     * @param {recoveredAccount} The address of the account to be recovered.
     * @param {accountSalt} The salt used to derive the account address.
     * @param {initData} The initialization data.
     */
    function initialize(
        address /* recoveredAccount */,
        bytes32 /* accountSalt */,
        bytes calldata initData
    ) public initializer {
        // NOTE: Temporary bypass, remove after the upgrade
        _owner = msg.sender;

        // address _dkimRegistry = 0x3D3935B3C030893f118a84C92C66dF1B9E4169d6;
        // address _verifier = 0x3E5f29a7cCeb30D5FCD90078430CA110c2985716;

        (
            address _dkimRegistry,
            address _verifier,
            address _commandHandler
        ) = abi.decode(initData, (address, address, address));

        dkimRegistry = IDKIMRegistry(_dkimRegistry);
        verifier = IVerifier(_verifier);

        commandHandler = _commandHandler;
        // commandHandler = 0x6f114A2628F358eaE4b798aC8803eF7b6F6C4257;

        timestampCheckEnabled = true;

        initCommandTemplates();
    }

    // NOTE: Temporary bypass, remove after the upgrade
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev initialize the command templates from thne command Handler
     */
    function initCommandTemplates() public {
        // load the command templates from the command handler
        string[][] memory acceptanceTemplates = acceptanceCommandTemplates();
        string[][] memory recoveryTemplates = recoveryCommandTemplates();

        // store the command templates
        for (uint256 idx = 0; idx < acceptanceTemplates.length; idx++) {
            commandTemplates[
                computeAcceptanceTemplateId(idx)
            ] = acceptanceTemplates[idx];
        }
        for (uint256 idx = 0; idx < recoveryTemplates.length; idx++) {
            commandTemplates[
                computeRecoveryTemplateId(idx)
            ] = recoveryTemplates[idx];
        }
    }

    /**
     * @dev Verify the proof
     * Recommended to use when proof verification is done on-chain or when called from another contract
     *
     * @notice Reverts if the proof is invalid
     *
     * @param recoveredAccount Account to be recovered
     * @param proof Proof data
     * @return isVerified if the proof is valid
     */
    function verifyProofStrict(
        address recoveredAccount,
        ProofData memory proof
    ) public view returns (bool) {
        // Parse the extra data
        EmailData memory emailData = abi.decode(proof.data, (EmailData));
        address _recoveredAccount = extractRecoveredAccountFromAcceptanceCommand(
                emailData.commandParams,
                emailData.templateIdx
            );

        require(
            recoveredAccount == _recoveredAccount,
            "invalid account in email"
        );

        uint256 templateId = uint256(0);
        if (emailData.isRecovery) {
            address account = IEmailRecoveryCommandHandler(commandHandler)
                .validateRecoveryCommand(
                    emailData.templateIdx,
                    emailData.commandParams
                );

            require(
                account == recoveredAccount,
                "invalid account in recovery command"
            );

            templateId = computeRecoveryTemplateId(emailData.templateIdx);
        } else {
            address account = IEmailRecoveryCommandHandler(commandHandler)
                .validateAcceptanceCommand(
                    emailData.templateIdx,
                    emailData.commandParams
                );

            require(
                account == recoveredAccount,
                "invalid account in acceptance command"
            );

            templateId = computeAcceptanceTemplateId(emailData.templateIdx);
        }

        require(emailData.isCodeExist == true, "isCodeExist is false");

        EmailProof memory emailProof = EmailProof({
            domainName: emailData.domainName,
            publicKeyHash: proof.publicInputs[0],
            timestamp: emailData.timestamp,
            maskedCommand: emailData.maskedCommand,
            emailNullifier: proof.publicInputs[1],
            accountSalt: emailData.accountSalt,
            isCodeExist: emailData.isCodeExist,
            proof: proof.proof
        });

        string[] memory template = commandTemplates[templateId];

        require(template.length != 0, "invalid template id");

        require(
            dkimRegistry.isDKIMPublicKeyHashValid(
                emailProof.domainName,
                emailProof.publicKeyHash
            ) == true,
            "invalid dkim public key hash"
        );

        require(
            usedNullifiers[emailProof.emailNullifier] == false,
            "email nullifier already used"
        );

        // TODO: match with the accountSalt added during initialization
        // require(
        //     accountSalt == emailAuthMsg.proof.accountSalt,
        //     "invalid account salt"
        // );

        require(
            timestampCheckEnabled == false ||
                emailProof.timestamp == 0 ||
                emailProof.timestamp > lastTimestamp,
            "invalid timestamp"
        );

        require(
            bytes(emailProof.maskedCommand).length <= verifier.commandBytes(),
            "invalid masked command length"
        );

        require(
            emailData.skippedCommandPrefix < verifier.commandBytes(),
            "invalid size of the skipped command prefix"
        );

        string memory trimmedMaskedCommand = removePrefix(
            emailProof.maskedCommand,
            emailData.skippedCommandPrefix
        );
        string memory expectedCommand = "";
        for (uint stringCase = 0; stringCase < 3; stringCase++) {
            expectedCommand = CommandUtils.computeExpectedCommand(
                emailData.commandParams,
                template,
                stringCase
            );
            if (Strings.equal(expectedCommand, trimmedMaskedCommand)) {
                break;
            }
            if (stringCase == 2) {
                revert("invalid command");
            }
        }

        require(
            verifier.verifyEmailProof(emailProof) == true,
            "invalid email proof"
        );

        // TODO: How to handle the nullifier update
        // usedNullifiers[emailProof.emailNullifier] = true;
        // if (timestampCheckEnabled && emailProof.timestamp != 0) {
        //     lastTimestamp = emailProof.timestamp;
        // }

        return (true);
    }

    /**
     * @dev Verify the proof and return the result and error message
     * Recommended to use when proof verification is done off-chain
     *
     * @notice Can be used to check the proof and get the error message
     * @notice No revert if the proof is invalid
     *
     * @param recoveredAccount Account to be recovered
     * @param proof Proof data
     * @return isVerified if the proof is valid
     * @return error message if the proof is invalid
     */
    // Lint Error: Cyclomatic complexity ( too many if else statements )
    function verifyProof(
        address recoveredAccount,
        ProofData memory proof
    ) public view returns (bool, string memory) {
        // Parse the extra data
        EmailData memory emailData = abi.decode(proof.data, (EmailData));
        address _recoveredAccount = extractRecoveredAccountFromAcceptanceCommand(
                emailData.commandParams,
                emailData.templateIdx
            );

        if (recoveredAccount != _recoveredAccount) {
            return (false, "invalid account in email");
        }

        uint256 templateId = uint256(0);
        if (emailData.isRecovery) {
            address account = IEmailRecoveryCommandHandler(commandHandler)
                .validateRecoveryCommand(
                    emailData.templateIdx,
                    emailData.commandParams
                );

            if (account != recoveredAccount) {
                return (false, "invalid account in recovery command");
            }

            templateId = computeRecoveryTemplateId(emailData.templateIdx);
        } else {
            address account = IEmailRecoveryCommandHandler(commandHandler)
                .validateAcceptanceCommand(
                    emailData.templateIdx,
                    emailData.commandParams
                );

            if (account != recoveredAccount) {
                return (false, "invalid account in acceptance command");
            }

            templateId = computeAcceptanceTemplateId(emailData.templateIdx);
        }

        if (emailData.isCodeExist == false) {
            return (false, "isCodeExist is false");
        }

        EmailProof memory emailProof = EmailProof({
            domainName: emailData.domainName,
            publicKeyHash: proof.publicInputs[0],
            timestamp: emailData.timestamp,
            maskedCommand: emailData.maskedCommand,
            emailNullifier: proof.publicInputs[1],
            accountSalt: emailData.accountSalt,
            isCodeExist: emailData.isCodeExist,
            proof: proof.proof
        });

        string[] memory template = commandTemplates[templateId];

        if (template.length == 0) {
            return (false, "invalid template id");
        }

        if (
            dkimRegistry.isDKIMPublicKeyHashValid(
                emailProof.domainName,
                emailProof.publicKeyHash
            ) == false
        ) {
            return (false, "invalid dkim public key hash");
        }

        if (usedNullifiers[emailProof.emailNullifier] == true) {
            return (false, "email nullifier already used");
        }

        // TODO: match with the accountSalt added during initialization
        // if (emailProof.accountSalt != emailData.accountSalt) {
        //     return (false, "invalid account salt");
        // }

        if (
            timestampCheckEnabled == true &&
            emailProof.timestamp < lastTimestamp
        ) {
            return (false, "invalid timestamp");
        }

        if (bytes(emailProof.maskedCommand).length > verifier.commandBytes()) {
            return (false, "invalid masked command length");
        }

        if (emailData.skippedCommandPrefix >= verifier.commandBytes()) {
            return (false, "invalid size of the skipped command prefix");
        }

        string memory trimmedMaskedCommand = removePrefix(
            emailProof.maskedCommand,
            emailData.skippedCommandPrefix
        );
        string memory expectedCommand = "";
        for (uint stringCase = 0; stringCase < 3; stringCase++) {
            expectedCommand = CommandUtils.computeExpectedCommand(
                emailData.commandParams,
                template,
                stringCase
            );
            if (Strings.equal(expectedCommand, trimmedMaskedCommand)) {
                break;
            }
            if (stringCase == 2) {
                return (false, "invalid command");
            }
        }

        if (verifier.verifyEmailProof(emailProof) == false) {
            return (false, "invalid email proof");
        }

        // TODO: How to handle the nullifier update
        // usedNullifiers[emailProof.emailNullifier] = true;
        // if (timestampCheckEnabled && emailProof.timestamp != 0) {
        //     lastTimestamp = emailProof.timestamp;
        // }

        return (true, "");
    }

    /**
     * @notice Returns a two-dimensional array of strings representing the command templates for an
     * acceptance by a new guardian.
     * @dev This is retrieved from the associated command handler. Developers can write their own
     * command handlers, this is useful for account implementations which require different data in
     * the command or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function acceptanceCommandTemplates()
        public
        view
        returns (string[][] memory)
    {
        return
            IEmailRecoveryCommandHandler(commandHandler)
                .acceptanceCommandTemplates();
    }

    /**
     * @notice Returns a two-dimensional array of strings representing the command templates for
     * email recovery.
     * @dev This is retrieved from the associated command handler. Developers can write their own
     * command handlers, this is useful for account implementations which require different data in
     * the command or if the email should be in a language that is not English.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function recoveryCommandTemplates()
        public
        view
        returns (string[][] memory)
    {
        return
            IEmailRecoveryCommandHandler(commandHandler)
                .recoveryCommandTemplates();
    }

    /**
     * @notice Extracts the account address to be recovered from the command parameters of an
     * acceptance email.
     * @dev This is retrieved from the associated command handler.
     * @param commandParams The command parameters of the acceptance email.
     * @param templateIdx The index of the acceptance command template.
     */
    function extractRecoveredAccountFromAcceptanceCommand(
        bytes[] memory commandParams,
        uint256 templateIdx
    ) public view returns (address) {
        return
            IEmailRecoveryCommandHandler(commandHandler)
                .extractRecoveredAccountFromAcceptanceCommand(
                    commandParams,
                    templateIdx
                );
    }

    /**
     * @notice Extracts the account address to be recovered from the command parameters of a
     * recovery email.
     * @dev This is retrieved from the associated command handler.
     * @param commandParams The command parameters of the recovery email.
     * @param templateIdx The index of the recovery command template.
     */
    function extractRecoveredAccountFromRecoveryCommand(
        bytes[] memory commandParams,
        uint256 templateIdx
    ) public view returns (address) {
        return
            IEmailRecoveryCommandHandler(commandHandler)
                .extractRecoveredAccountFromRecoveryCommand(
                    commandParams,
                    templateIdx
                );
    }

    // TODO: Check if it's required
    /// @notice Calculates a unique command template ID for an acceptance command template using its
    /// index.
    /// @dev Encodes the email account recovery version ID, "ACCEPTANCE", and the template index,
    /// then uses keccak256 to hash these values into a uint ID.
    /// @param templateIdx The index of the acceptance command template.
    /// @return uint The computed uint ID.
    function computeAcceptanceTemplateId(
        uint256 templateIdx
    ) public pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        EMAIL_GUARDIAN_VERIFIER_VERSION_ID,
                        "ACCEPTANCE",
                        templateIdx
                    )
                )
            );
    }

    // TODO: Check if it's required
    /// @notice Calculates a unique ID for a recovery command template using its index.
    /// @dev Encodes the email account recovery version ID, "RECOVERY", and the template index,
    /// then uses keccak256 to hash these values into a uint256 ID.
    /// @param templateIdx The index of the recovery command template.
    /// @return uint The computed uint ID.
    function computeRecoveryTemplateId(
        uint256 templateIdx
    ) public pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        EMAIL_GUARDIAN_VERIFIER_VERSION_ID,
                        "RECOVERY",
                        templateIdx
                    )
                )
            );
    }

    /// @notice Enables or disables the timestamp check.
    /// @dev This function can only be called by the controller.
    /// @param _enabled Boolean flag to enable or disable the timestamp check.
    function setTimestampCheckEnabled(bool _enabled) public {
        timestampCheckEnabled = _enabled;
    }

    function removePrefix(
        string memory str,
        uint numBytes
    ) private pure returns (string memory) {
        require(
            numBytes <= bytes(str).length,
            "Invalid size of the removed bytes"
        );

        bytes memory strBytes = bytes(str);
        bytes memory result = new bytes(strBytes.length - numBytes);

        for (uint i = numBytes; i < strBytes.length; i++) {
            result[i - numBytes] = strBytes[i];
        }

        return string(result);
    }
}
