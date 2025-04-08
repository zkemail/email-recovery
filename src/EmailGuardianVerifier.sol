// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IDKIMRegistry} from "@zk-email/contracts/DKIMRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IGuardianVerifier} from "./interfaces/IGuardianVerifier.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IEmailRecoveryCommandHandler} from "./interfaces/IEmailRecoveryCommandHandler.sol";
import {CommandUtils} from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import {IVerifier, EmailProof} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

/**
 * @title EmailGuardianVerifier
 * @notice Provides a mechanism for guardian verification using email-based proofs.
 * @dev The underlying IGuardianVerifier provides the interface for proof verification.
 */
contract EmailGuardianVerifier is IGuardianVerifier, Initializable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    CONSTANTS & STORAGE                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Version ID for the email guardian verifier, required for template ID computation
    uint8 public constant EMAIL_GUARDIAN_VERIFIER_VERSION_ID = 1;

    // Owner of the contract
    // NOTE: Temporary bypass, recommended to use Ownable.sol or remove in the final version
    address private _owner;

    // Command handler address
    address public commandHandler;

    // Salt used to derive the account address
    bytes32 public accountSalt;

    // Boolean flag to enable or disable timestamp check
    bool public timestampCheckEnabled;

    // Last timestamp when a proof was verified
    uint256 public lastTimestamp;

    // Mapping to store the command templates for acceptance and recovery
    mapping(uint256 templateId => string[] template) public commandTemplates;

    // Mapping to store the used email nullifiers for replay protection
    mapping(bytes32 emailNullifier => bool used) public usedNullifiers;

    // DKIM registry contract
    IDKIMRegistry public dkimRegistry;

    // ZK Email Verifier contract
    IVerifier public verifier;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     TYPE DECLARATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Struct to hold proof data
    struct EmailData {
        // Template index for the command
        uint256 templateIdx;
        // Command parameters for the email
        bytes[] commandParams;
        // Skipped command prefix
        uint256 skippedCommandPrefix;
        // Domain name for the email
        string domainName;
        // Timestamp of the email
        uint256 timestamp;
        // Masked command for the email
        string maskedCommand;
        // Account salt used to derive the account address
        bytes32 accountSalt;
        // If the code exists
        bool isCodeExist;
        // If the email is for recovery
        bool isRecovery;
        // Recovery data hash ( only required for recovery verification )
        bytes32 recoveryDataHash;
        // Public key hash for the email
        bytes32 publicKeyHash;
        // Email nullifier
        bytes32 emailNullifier;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Account in the email command is not the same as the account to be recovered
    error InvalidAccountInCommand(
        string commandType,
        address account,
        address expectedAccount
    );

    // isCodeExit == false in the proof
    error CodeDoesNotExist();

    // Template ID is not present in the command templates
    error InvalidTemplateId(uint256 templateId);

    // DKIM public key hash is not valid
    error InvalidDKIMPublicKeyHash();

    // Email nullifier is already used
    error EmailNullifierAlreadyUsed();

    // Account salt is not the same as the salt used to derive the account address
    error InvalidAccountSalt(bytes32 accontSalt, bytes32 expectedAccountSalt);

    // Timestamp is invalid
    error InvalidTimestamp();

    // Masked command length is invalid
    error InvalidMaskedCommandLength();

    // Skipped command prefix is invalid
    error InvalidSkippedCommandPrefix();

    // Command is invalid
    error InvalidCommand();

    // Email proof is invalid
    error InvalidEmailProof();

    // Recovery data hash is invalid
    error InvalidRecoveryDataHash();

    /**
     * @dev The initializer is disabled to prevent the implementation contract from being initialized
     */
    constructor() {
        _disableInitializers();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          FUNCTIONS                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Returns the owner of the contract.
     *
     * @return address The address of the owner.
     * @notice This function is a temporary bypass and should be removed after the upgrade.
     */
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Returns the address of the DKIM registry contract.
     *
     * @return address The address of the DKIM registry contract.
     */
    function dkimRegistryAddr() public view returns (address) {
        return address(dkimRegistry);
    }

    /**
     * @dev Returns the address of the verifier contract.
     *
     * @return address The address of the verifier contract.
     */
    function verifierAddr() public view returns (address) {
        return address(verifier);
    }

    /**
     * @dev Initializes the contract with the DKIM registry, verifier, and command handler addresses.
     * @notice Addresses are hardcoded for the initial implementation.
     *
     * @param {account} The address of the account to be recovered.
     * @param _accountSalt The salt used to derive the account address.
     * @param initData The initialization data.
     */
    function initialize(
        address /* account */,
        bytes32 _accountSalt,
        bytes calldata initData
    ) public initializer {
        // NOTE: Temporary bypass, remove after the upgrade
        _owner = msg.sender;

        (
            address _dkimRegistry,
            address _verifier,
            address _commandHandler
        ) = abi.decode(initData, (address, address, address));

        dkimRegistry = IDKIMRegistry(_dkimRegistry);
        verifier = IVerifier(_verifier);
        commandHandler = _commandHandler;

        timestampCheckEnabled = true;

        accountSalt = _accountSalt;

        initCommandTemplates();
    }

    /**
     * @dev initialize the command templates by retrieving the tempaltes from the command Handler
     */
    function initCommandTemplates() public {
        string[][] memory acceptanceTemplates = acceptanceCommandTemplates();
        string[][] memory recoveryTemplates = recoveryCommandTemplates();

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
     * Recommended to be used when nullifier based check for replay protection are required & not handeled at higher level
     * e.g. Recovery functions ( handleAcceptance & handleRecovery )
     *
     * @notice Nullifier based check is handled here
     * @notice Timestamp check of when the proof was generated is handled here
     * @notice Reverts if the proof is invalid
     *
     * @param account Account to be recovered
     * @param proof Proof data
     * proof.data: EmailData
     * proof.proof: zk-SNARK proof
     *
     * NOTE: Gas optimisation possible by only decoding the proof data once in this function rather in tryVerify as well
     *
     * @return isVerified if the proof is valid
     */
    function verifyProof(
        address account,
        ProofData memory proof
    ) public returns (bool) {
        EmailData memory emailData = abi.decode(proof.data, (EmailData));

        bytes32 emailNullifier = emailData.emailNullifier;
        require(
            usedNullifiers[emailNullifier] == false,
            EmailNullifierAlreadyUsed()
        );

        require(
            timestampCheckEnabled == false ||
                emailData.timestamp == 0 ||
                emailData.timestamp > lastTimestamp,
            InvalidTimestamp()
        );

        bool isVerified = tryVerifyProof(account, proof);

        if (isVerified) {
            usedNullifiers[emailNullifier] = true;
            if (timestampCheckEnabled && emailData.timestamp != 0) {
                lastTimestamp = emailData.timestamp;
            }
        }

        return isVerified;
    }

    /**
     * @dev Verify the proof
     * Recommended to use when only proof verification is required
     * View function to check if the proof is valid
     *
     * @notice Replay protection is assumed to be handled by the caller
     * @notice Reverts if the proof is invalid
     *
     * @param account Account to be recovered
     * @param proof Proof data
     * proof.data: EmailData
     * proof.proof: zk-SNARK proof
     *
     * @return isVerified if the proof is valid
     */
    function tryVerifyProof(
        address account,
        ProofData memory proof
    ) public view returns (bool) {
        // Parse the extra data
        EmailData memory emailData = abi.decode(proof.data, (EmailData));

        EmailProof memory emailProof = EmailProof({
            domainName: emailData.domainName,
            publicKeyHash: emailData.publicKeyHash,
            timestamp: emailData.timestamp,
            maskedCommand: emailData.maskedCommand,
            emailNullifier: emailData.emailNullifier,
            accountSalt: emailData.accountSalt,
            isCodeExist: emailData.isCodeExist,
            proof: proof.proof
        });

        uint256 templateId = uint256(0);
        if (emailData.isRecovery) {
            address _account = IEmailRecoveryCommandHandler(commandHandler)
                .validateRecoveryCommand(
                    emailData.templateIdx,
                    emailData.commandParams
                );

            require(
                account == _account,
                InvalidAccountInCommand("recovery", _account, account)
            );

            templateId = computeRecoveryTemplateId(emailData.templateIdx);

            bytes32 _recoveryDataHash = IEmailRecoveryCommandHandler(
                commandHandler
            ).parseRecoveryDataHash(
                    emailData.templateIdx,
                    emailData.commandParams
                );

            require(
                emailData.recoveryDataHash == _recoveryDataHash,
                InvalidRecoveryDataHash()
            );
        } else {
            address _account = IEmailRecoveryCommandHandler(commandHandler)
                .validateAcceptanceCommand(
                    emailData.templateIdx,
                    emailData.commandParams
                );

            require(
                account == _account,
                InvalidAccountInCommand("acceptance", _account, account)
            );

            templateId = computeAcceptanceTemplateId(emailData.templateIdx);

            require(emailData.isCodeExist == true, CodeDoesNotExist());
        }

        string[] memory template = commandTemplates[templateId];
        require(template.length != 0, InvalidTemplateId(templateId));

        require(
            dkimRegistry.isDKIMPublicKeyHashValid(
                emailProof.domainName,
                emailProof.publicKeyHash
            ) == true,
            InvalidDKIMPublicKeyHash()
        );

        require(
            accountSalt == emailProof.accountSalt,
            InvalidAccountSalt(emailProof.accountSalt, accountSalt)
        );

        require(
            bytes(emailProof.maskedCommand).length <= verifier.commandBytes(),
            InvalidMaskedCommandLength()
        );

        require(
            emailData.skippedCommandPrefix < verifier.commandBytes(),
            InvalidSkippedCommandPrefix()
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
                revert InvalidCommand();
            }
        }

        require(
            verifier.verifyEmailProof(emailProof) == true,
            InvalidEmailProof()
        );

        return true;
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

    /**
     * @dev Sets the timestamp check enabled or disabled.
     *
     * @param _enabled bool to enable or disable the timestamp check.
     * @notice This function is currently restricted to the owner of the contract.
     */
    function setTimestampCheckEnabled(bool _enabled) public {
        require(msg.sender == _owner, "Only owner can set this");

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
