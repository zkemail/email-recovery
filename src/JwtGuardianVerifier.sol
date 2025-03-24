// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {IDKIMRegistry} from "@zk-email/contracts/DKIMRegistry.sol";

import {IGuardianVerifier} from "./interfaces/IGuardianVerifier.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IVerifier, EmailProof} from "./interfaces/IJwtVerifier.sol";

/**
 * @title JwtGuardianVerifier
 * @notice Provides a mechanism for guardian verification using jwt token proofs
 * @dev The underlying IGuardianVerifier provides the interface for proof verification.
 */
contract JwtGuardianVerifier is IGuardianVerifier, Initializable {
    // NOTE: Temporary bypass, remove after the upgrade
    address _owner;

    bool public timestampCheckEnabled;
    uint256 public lastTimestamp;

    mapping(bytes32 emailNullifier => bool used) public usedNullifiers;

    IDKIMRegistry public jwtRegistry;

    IVerifier public verifier;

    struct JwtData {
        string domainName;
        uint256 timestamp;
        string maskedCommand;
        bytes32 accountSalt;
        bool isCodeExist;
        bool isRecovery;
    }

    /// @notice Returns the address of the JWT registry contract.
    /// @return address The address of the DKIM registry contract.
    function jwtRegistryAddr() public view returns (address) {
        return address(jwtRegistry);
    }

    /// @notice Returns the address of the verifier contract.
    /// @return address The Address of the verifier contract.
    function verifierAddr() public view returns (address) {
        return address(verifier);
    }

    constructor() {}

    //TODO: Maybe accountSalt can be passed while intializing the contract
    /**
     * @dev Initializes the contract with the JWT registry, verifier addresses.
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

        (address _jwtRegistry, address _verifier) = abi.decode(
            initData,
            (address, address)
        );

        jwtRegistry = IDKIMRegistry(_jwtRegistry);
        verifier = IVerifier(_verifier);

        timestampCheckEnabled = true;
    }

    // NOTE: Temporary bypass, remove after the upgrade
    function owner() public view returns (address) {
        return _owner;
    }

    /**
     * @dev Verify the proof
     * Recommended to use when proof verification is done on-chain or when called from another contract
     *
     * @notice Reverts if the proof is invalid
     *
     * @param recoveredAccount Account to be recovered
     * @param proof Proof data
     * proof.data: JwtData
     * proof.publicInputs: [publicKeyHash, emailNullifier]
     * proof.proof: zk-SNARK proof
     *
     * @return isVerified if the proof is valid
     */
    function verifyProofStrict(
        address recoveredAccount,
        ProofData memory proof
    ) public view returns (bool) {
        // Parse the extra data
        JwtData memory jwtData = abi.decode(proof.data, (JwtData));

        require(jwtData.isCodeExist == true, "isCodeExist is false");

        EmailProof memory jwtProof = EmailProof({
            domainName: jwtData.domainName,
            publicKeyHash: proof.publicInputs[0],
            timestamp: jwtData.timestamp,
            maskedCommand: jwtData.maskedCommand,
            emailNullifier: proof.publicInputs[1],
            accountSalt: jwtData.accountSalt,
            isCodeExist: jwtData.isCodeExist,
            proof: proof.proof
        });

        // require(
        //     jwtRegistry.isDKIMPublicKeyHashValid(
        //         jwtProof.domainName,
        //         jwtProof.publicKeyHash
        //     ) == true,
        //     "invalid dkim public key hash"
        // );

        require(
            usedNullifiers[jwtProof.emailNullifier] == false,
            "email nullifier already used"
        );

        // TODO: match with the accountSalt added during initialization
        // require(
        //     accountSalt == jwtProof.accountSalt,
        //     "invalid account salt"
        // );

        // require(
        //     timestampCheckEnabled == false ||
        //         jwtProof.timestamp == 0 ||
        //         jwtProof.timestamp > lastTimestamp,
        //     "invalid timestamp"
        // );

        // require(
        //     bytes(jwtProof.maskedCommand).length <= verifier.getCommandBytes(),
        //     "invalid masked command length"
        // );

        require(
            verifier.verifyEmailProof(jwtProof) == true,
            "invalid email proof"
        );

        // TODO: How to handle the nullifier update
        // usedNullifiers[jwtProof.emailNullifier] = true;
        // if (timestampCheckEnabled && jwtProof.timestamp != 0) {
        //     lastTimestamp = jwtProof.timestamp;
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
     * proof.data: JwtData
     * proof.publicInputs: [publicKeyHash, emailNullifier]
     * proof.proof: zk-SNARK proof
     *
     * @return isVerified if the proof is valid
     * @return error message if the proof is invalid
     */
    // Lint Error: Cyclomatic complexity ( too many if else statements )
    function verifyProof(
        address recoveredAccount,
        ProofData memory proof
    ) public view returns (bool, string memory) {
        JwtData memory jwtData = abi.decode(proof.data, (JwtData));

        if (jwtData.isCodeExist == false) {
            return (false, "isCodeExist is false");
        }

        EmailProof memory jwtProof = EmailProof({
            domainName: jwtData.domainName,
            publicKeyHash: proof.publicInputs[0],
            timestamp: jwtData.timestamp,
            maskedCommand: jwtData.maskedCommand,
            emailNullifier: proof.publicInputs[1],
            accountSalt: jwtData.accountSalt,
            isCodeExist: jwtData.isCodeExist,
            proof: proof.proof
        });

        if (
            jwtRegistry.isDKIMPublicKeyHashValid(
                jwtProof.domainName,
                jwtProof.publicKeyHash
            ) == false
        ) {
            return (false, "invalid dkim public key hash");
        }
        // require(
        //     jwtRegistry.isDKIMPublicKeyHashValid(
        //         jwtProof.domainName,
        //         jwtProof.publicKeyHash
        //     ) == true,
        //     "invalid dkim public key hash"
        // );

        if (usedNullifiers[jwtProof.emailNullifier] == true) {
            return (false, "email nullifier already used");
        }

        // TODO: match with the accountSalt added during initialization
        // if (emailProof.accountSalt != emailData.accountSalt) {
        //     return (false, "invalid account salt");
        // }

        // if (
        //     timestampCheckEnabled == true && jwtProof.timestamp < lastTimestamp
        // ) {
        //     return (false, "invalid timestamp");
        // }

        // if (bytes(jwtProof.maskedCommand).length > verifier.getCommandBytes()) {
        //     return (false, "invalid masked command length");
        // }

        if (verifier.verifyEmailProof(jwtProof) == false) {
            return (false, "invalid email proof");
        }

        // TODO: How to handle the nullifier update
        // usedNullifiers[jwtProof.emailNullifier] = true;
        // if (timestampCheckEnabled && jwtProof.timestamp != 0) {
        //     lastTimestamp = jwtProof.timestamp;
        // }

        return (true, "");
    }

    /// @notice Enables or disables the timestamp check.
    /// @dev This function can only be called by the controller.
    /// @param _enabled Boolean flag to enable or disable the timestamp check.
    function setTimestampCheckEnabled(bool _enabled) public {
        timestampCheckEnabled = _enabled;
    }
}
