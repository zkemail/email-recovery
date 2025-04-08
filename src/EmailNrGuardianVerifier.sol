// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IDKIMRegistry} from "@zk-email/contracts/DKIMRegistry.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IGuardianVerifier} from "./interfaces/IGuardianVerifier.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IEmailRecoveryCommandHandler} from "./interfaces/IEmailRecoveryCommandHandler.sol";
import {CommandUtils} from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";

import {IVerifier} from "./interfaces/IHonkVerifier.sol";

/**
 * @title EmailGuardianVerifier
 * @notice Provides a mechanism for guardian verification using email-noir-circuit-based proofs for client side proving
 * @dev The underlying IGuardianVerifier provides the interface for proof verification.
 */
contract EmailNrGuardianVerifier is IGuardianVerifier, Initializable {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         STORAGE                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Owner of the contract
    // NOTE: Temporary bypass, remove after the upgrade
    address private _owner;

    // Salt used to derive the account address
    bytes32 public accountSalt;

    // Boolean flag to enable or disable timestamp check
    bool public timestampCheckEnabled;

    // Last timestamp when a proof was verified
    uint256 public lastTimestamp;

    // Mapping to store used nullifiers
    mapping(bytes32 emailNullifier => bool used) public usedNullifiers;

    // DKIM registry contract
    IDKIMRegistry public dkimRegistry;

    // zkemail.nr honk verifier contract
    IVerifier public verifier;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     TYPE DECLARATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Proof data structure
    struct EmailData {
        // Domain name of the email
        string domainName;
        // Timestamp of the proof
        uint256 timestamp;
        // Account salt used to derive the account address
        bytes32 accountSalt;
        // Public key hash for the email
        bytes32 publicKeyHash;
        // Email nullifier
        bytes32 emailNullifier;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // DKIM public key hash is not valid
    error InvalidDKIMPublicKeyHash();

    // Email nullifier is already used
    error EmailNullifierAlreadyUsed();

    // Account salt is not the same as the salt used to derive the account address
    error InvalidAccountSalt(bytes32 accontSalt, bytes32 expectedAccountSalt);

    // Timestamp is invalid
    error InvalidTimestamp();

    // Email proof is invalid
    error InvalidEmailProof();

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

        (address _dkimRegistry, address _verifier) = abi.decode(
            initData,
            (address, address)
        );

        dkimRegistry = IDKIMRegistry(_dkimRegistry);
        verifier = IVerifier(_verifier);

        timestampCheckEnabled = true;

        accountSalt = _accountSalt;
    }

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
     * @dev Verify the proof
     * Recommended to be used when nullifier based check for replay protection are required & not handeled at higher level
     * e.g. Email recovery functions ( handleAcceptance & handleRecovery )
     *
     * @notice Nullifier based check is handled here
     * @notice Timestamp check of when the proof was generated is handled here
     * @notice Reverts if the proof is invalid
     *
     * @param account Account to be recovered
     * @param proof Proof data
     * proof.data: EmailData
     * proof.proof: zk proof
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
     * proof.proof: zk proof
     *
     * @return isVerified if the proof is valid
     */
    function tryVerifyProof(
        address account,
        ProofData memory proof
    ) public view returns (bool) {
        // Parse the extra data
        EmailData memory emailData = abi.decode(proof.data, (EmailData));

        // TODO: How to handle dkimRegistry validation in case of noir circuits
        // require(
        //     dkimRegistry.isDKIMPublicKeyHashValid(
        //         emailData.domainName,
        //         emailProof.publicKeyHash
        //     ) == true,
        //     InvalidDKIMPublicKeyHash()
        // );

        require(
            accountSalt == emailData.accountSalt,
            InvalidAccountSalt(emailData.accountSalt, accountSalt)
        );

        bytes32[] memory publicInputs = new bytes32[](2);
        publicInputs[0] = emailData.publicKeyHash;
        publicInputs[1] = emailData.emailNullifier;

        require(
            verifier.verify(proof.proof, publicInputs) == true,
            InvalidEmailProof()
        );

        return (true);
    }

    /**
     * @dev Sets the timestamp check enabled or disabled.
     *
     * @param _enabled bool to enable or disable the timestamp check.
     * @notice This function is currently restricted to the owner of the contract.
     */
    function setTimestampCheckEnabled(bool _enabled) public {
        timestampCheckEnabled = _enabled;
    }
}
