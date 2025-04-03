// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         STORAGE                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Owner of the contract
    // NOTE: Temporary bypass, recommended to use Ownable.sol or remove in the final version
    address private _owner;

    // Salt used to derive the account address
    bytes32 public accountSalt;

    // Boolean flag to enable or disable timestamp check
    bool public timestampCheckEnabled;

    // Last timestamp when a proof was verified
    uint256 public lastTimestamp;

    // Mapping to store used nullifiers
    mapping(bytes32 nullifier => bool used) public usedNullifiers;

    // JWT registry contract
    IDKIMRegistry public jwtRegistry;

    // ZK JWT verifier contract
    IVerifier public verifier;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     TYPE DECLARATIONS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Proof data structure
    struct JwtData {
        // The domain name for jwt
        string domainName;
        // Timestamp of the proof
        uint256 timestamp;
        // The jwt claim
        string maskedCommand;
        // Account salt used to derive the account address
        bytes32 accountSalt;
        // If the code exists
        bool isCodeExist;
        // If the proof is a recovery proof
        bool isRecovery;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // isCodeExit == false in the proof
    error CodeDoesNotExist();

    // public key hash is not valid
    error InvalidPublicKeyHash();

    // Account salt is not the same as the salt used to derive the account address
    error InvalidAccountSalt(bytes32 accontSalt, bytes32 expectedAccountSalt);

    // Timestamp is invalid
    error InvalidTimestamp();

    // JWT nullifier is already used
    error JWTNullifierAlreadyUsed();

    // JWT proof is invalid
    error InvalidJWTProof();

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
     * @dev Returns the address of the JWT registry contract.
     *
     * @return address The address of the JWT registry contract.
     */
    function jwtRegistryAddr() public view returns (address) {
        return address(jwtRegistry);
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
     * @dev Initializes the contract with the JWT registry, verifier addresses.
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

        (address _jwtRegistry, address _verifier) = abi.decode(
            initData,
            (address, address)
        );

        jwtRegistry = IDKIMRegistry(_jwtRegistry);
        verifier = IVerifier(_verifier);

        timestampCheckEnabled = true;

        accountSalt = _accountSalt;
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
     * proof.data: JwtData
     * proof.publicInputs: [publicKeyHash, emailNullifier]
     * proof.proof: zk-SNARK proof
     *
     * NOTE: Specific claim is not yet verified
     * NOTE: JWTRegistry check is disabled
     * NOTE: Gas optimisation possible by only decoding the proof data once in this function rather in tryVerify as well
     *
     * @return isVerified if the proof is valid
     */
    function verifyProof(
        address account,
        ProofData memory proof
    ) public returns (bool) {
        JwtData memory jwtData = abi.decode(proof.data, (JwtData));

        bytes32 jwtNullifier = proof.publicInputs[1];
        require(
            usedNullifiers[jwtNullifier] == false,
            JWTNullifierAlreadyUsed()
        );

        require(
            timestampCheckEnabled == false ||
                jwtData.timestamp == 0 ||
                jwtData.timestamp > lastTimestamp,
            InvalidTimestamp()
        );

        bool isVerified = tryVerifyProof(account, proof);

        if (isVerified) {
            usedNullifiers[jwtNullifier] = true;
            if (timestampCheckEnabled && jwtData.timestamp != 0) {
                lastTimestamp = jwtData.timestamp;
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
     * proof.data: JwtData
     * proof.publicInputs: [publicKeyHash, emailNullifier]
     * proof.proof: zk-SNARK proof
     *
     * @return isVerified if the proof is valid
     */
    function tryVerifyProof(
        address account,
        ProofData memory proof
    ) public view returns (bool) {
        // Parse the extra data
        JwtData memory jwtData = abi.decode(proof.data, (JwtData));

        require(jwtData.isCodeExist == true, CodeDoesNotExist());

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

        require(
            jwtRegistry.isDKIMPublicKeyHashValid(
                jwtProof.domainName,
                jwtProof.publicKeyHash
            ) == true,
            InvalidPublicKeyHash()
        );

        require(
            accountSalt == jwtProof.accountSalt,
            InvalidAccountSalt(jwtProof.accountSalt, accountSalt)
        );

        // TODO: Handle the specific claim (command) check
        // require(
        //     bytes(jwtProof.maskedCommand).length <= verifier.getCommandBytes(),
        //     "invalid masked command length"
        // );

        require(verifier.verifyEmailProof(jwtProof) == true, InvalidJWTProof());

        return (true);
    }

    /**
     * @dev Enables or disables the timestamp check.
     * @notice This function can only be called by the owner.
     *
     * @param _enabled Boolean flag to enable or disable the timestamp check.
     */
    function setTimestampCheckEnabled(bool _enabled) public {
        require(
            msg.sender == _owner,
            "Only the owner can set the timestamp check"
        );

        timestampCheckEnabled = _enabled;
    }
}
