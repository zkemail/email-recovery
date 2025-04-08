// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IGuardianVerifier
 * @notice Interface for the verifier contract
 * @dev A standard interface for verification based on several proof scheme
 *
 * This contract contains the logic for the verifier initialisation & verification
 * It's developed to support proof schemes like zkEmail groth16, zkEmail.nr, zk JWT, but not limited to these
 *
 * @dev This contract is deployed as a minimal proxy contract (Clones: EIP1167) for a new guardian specific to
 * a recovered account. Thus the guardian verifier is recommend to implement
 * Initializable(https://docs.openzeppelin.com/contracts/4.x/api/proxy#Initializable)
 */
interface IGuardianVerifier {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    DATA STRUCTURES                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Proof data required proof verification
    struct ProofData {
        /// @dev Proof
        bytes proof;
        /// @dev Arbitrary Data required for verification
        bytes data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    FUNCTIONS                               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Initialize the contract with ERC1967 proxy deployement
     * Deployer is AccountRecovery module contract
     *
     * @param account Account to be recovered
     * @param accountSalt Account salt
     * @param initData Initialization data
     */
    function initialize(
        address account,
        bytes32 accountSalt,
        bytes calldata initData
    ) external;

    /**
     * @dev Verification logic of the proof
     * To be used when nullifier based check for replay protection are required & not handeled at higher level
     * e.g. Recovery functions ( handleAcceptance & handleRecovery )
     *
     * @notice Replay protection is handled by the verifier
     * @notice Reverts if the proof is invalid
     *
     * @param account Account to be recovered
     * @param proof Proof data
     * @return isVerified if the proof is valid
     *
     */
    function verifyProof(
        address account,
        ProofData memory proof
    ) external returns (bool isVerified);

    /**
     * @dev Verification logic of the proof
     * Recommended to use when only proof verification is required
     * View function to check if the proof is valid
     *
     * @notice Replay protection is assumed to be handled by the caller
     * @notice Reverts if the proof is invalid
     *
     * @param account Account to be recovered
     * @param proof Proof data
     * @return isVerified if the proof is valid
     */
    function tryVerifyProof(
        address account,
        ProofData memory proof
    ) external view returns (bool isVerified);
}
