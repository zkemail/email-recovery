// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";


/**
 * @title EOA712Verifier
 * @notice A contract that verifies EIP-712 signatures from EOA guardians using OpenZeppelin’s ECDSA and SignatureChecker utilities.
 */
contract SimpleRecoveryVerifier {
    using ECDSA for bytes32;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     ERRORS & EVENTS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InvalidSignature(address recoveredSigner, bytes signature);

    event GuardianVerified(
        address indexed signer,
        address indexed recoveredAccount,
        uint256 templateIdx,
        bytes32 commandParamsHash
    );
 
    mapping(address => mapping(address => uint256)) private nonces;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 EIP-712 DOMAIN PARAMETERS                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    string private constant NAME = "EOAGuardianVerifier";
    string private constant VERSION = "1.0.0";

    bytes32 private constant _EIP712_DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 private constant _GUARDIAN_TYPEHASH = keccak256(
        "GuardianAcceptance(address recoveredAccount,uint256 templateIdx,bytes32 commandParamsHash, uint256 nonce)"
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*       PUBLIC FUNCTION: VERIFY EOA GUARDIAN SIGNATURE        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Verifies an EOA-based guardian’s EIP-712 signature.
     * @param recoveredAccount The account that is being protected.
     * @param templateIdx Numeric index indicating the acceptance template.
     * @param commandParams Variable-length acceptance parameters (encoded bytes).
     * @param signature The ECDSA signature from the guardian.
     * @return signer The address recovered from the signature (reverts if invalid).
     */
    function verifyEOAGuardian(
        address recoveredAccount,
        uint256 templateIdx,
        bytes[] memory commandParams,
        bytes memory signature
    ) public virtual returns (address signer) {
        // Encode command parameters and hash them
        bytes memory encodedParams = abi.encode(commandParams);
        bytes32 commandParamsHash = keccak256(encodedParams);

        // Create the struct hash for GuardianAcceptance
        bytes32 structHash = keccak256(
            abi.encode(
                _GUARDIAN_TYPEHASH,
                recoveredAccount,
                templateIdx,
                commandParamsHash,
                nonces[msg.sender][recoveredAccount]++
            )
        );

        // Create the final EIP-712 digest
        bytes32 digest = toTypedDataHash(_domainSeparatorV4(), structHash);

        // Recover the signer from the digest and signature
        address recoveredSigner = ECDSA.recover(digest, signature);
       
        // Check the validity of the signature
        bool isValid = SignatureChecker.isValidSignatureNow(
            recoveredSigner,
            digest,
            signature
        );

        if (!isValid) {
            revert InvalidSignature(recoveredSigner, signature);
        }

        signer = recoveredSigner;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*             INTERNAL FUNCTION: DOMAIN SEPARATOR            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Calculates the EIP-712 domain separator for the current chain.
     */
    function _domainSeparatorV4() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                _EIP712_DOMAIN_TYPEHASH,
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*         INTERNAL FUNCTION: CREATE TYPED DATA HASH          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Combines the domain separator and struct hash into a single typed data hash.
     */
    function toTypedDataHash(bytes32 domainSeparator, bytes32 structHash)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               PUBLIC FUNCTION: GET DOMAIN SEPARATOR        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @notice Returns the current domain separator.
     * @return The EIP-712 domain separator.
     */
    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function getNonce(address account, address guardian) public view returns (uint256) {
    return nonces[account][guardian];
}

}
