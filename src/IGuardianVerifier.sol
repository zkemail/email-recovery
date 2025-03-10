// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

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
     * @dev Initialize the contract initialised with ERC1967 proxy deployement
     * controller can be set to gate the access to initVerifier
     *
     * @param recoveredAccount Account to be recovered
     * @param controller Controller address
     */
    function initialize(address recoveredAccount, address controller) external;

    /**
     * @dev Initialize the verifier with initialization data
     *
     * @param recoveredAccount Account to be recovered
     * @param initData Initialization data
     *
     * @notice This function should be only allowed to be called by the controller
     */
    function initVerifier(
        address recoveredAccount,
        bytes calldata initData
    ) external;

    /**
     * @dev Verification logic of the proof
     *
     * @param recoveredAccount Account to be recovered
     * @param proof Proof data
     * @return true if the proof is valid
     */
    function verifyProof(
        address recoveredAccount,
        ProofData memory proof
    ) external view returns (bool);
}
