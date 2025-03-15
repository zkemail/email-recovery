// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/**
 * @title IGuardianVerifier
 * @notice Interface for the verifier contract
 * @dev A standard interface for verification based on several proof scheme
 *
 * This contract contains the logic for the verifier initialisation & verification
 * It's developed to support proof schemes like zkEmail groth16, zkEmail.nr, zk JWT, but not limited to these
 */
interface IGuardianVerifier {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    DATA STRUCTURES                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Proof data required proof verification
    struct ProofData {
        /// @dev Proof
        bytes proof;
        /// @dev Public inputs required for verification
        bytes32[] publicInputs;
        /// @dev Additional Data required for verification
        bytes data;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    FUNCTIONS                               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /**
     * @dev Initialize the contract with ERC1967 proxy deployement
     * Deployer is AccountRecovery module contract
     *
     * @param recoveredAccount Account to be recovered
     * @param accountSalt Account salt
     * @param initData Initialization data
     */
    function initialize(
        address recoveredAccount,
        bytes32 accountSalt,
        bytes calldata initData
    ) external;

    /**
     * @dev Verification logic of the proof
     * @notice Reverts if the proof is invalid
     *
     * @param recoveredAccount Account to be recovered
     * @param proof Proof data
     * @return isVerified if the proof is valid
     *
     */
    function verifyProofStrict(
        address recoveredAccount,
        ProofData memory proof
    ) external view returns (bool isVerified);

    /**
     * @dev Verification logic of the proof
     * @notice Returns error message if the proof is invalid
     *
     * @param recoveredAccount Account to be recovered
     * @param proof Proof data
     * @return isVerified if the proof is valid
     * @return error message if the proof is invalid
     */
    function verifyProof(
        address recoveredAccount,
        ProofData memory proof
    ) external view returns (bool isVerified, string memory error);
}
