// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IGuardianVerifier} from "./interfaces/IGuardianVerifier.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Email Account Recovery Contract
/// @notice Provides mechanisms for account recovery, leveraging guardian verifiers.
/// @dev This contract is abstract and requires implementation of several methods for configuring a
/// new guardian and recovering an account contract.
abstract contract EmailAccountRecovery {
    uint8 public constant EMAIL_ACCOUNT_RECOVERY_VERSION_ID = 2;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ERRORS                                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InvalidGuardianImplementation();
    error InvalidProxyDeployment();
    error GuardianNotDeployed();
    error ProofVerificationFailed();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Functions                               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns if the account to be recovered has already activated the controller (this
    /// contract).
    /// @dev This function is virtual and should be implemented by inheriting contracts.
    /// @dev This function helps a relayer inactivate the guardians' data after the account
    /// inactivates the controller (this contract).
    /// @param account The address of the account to be recovered.
    /// @return bool True if the account is already activated, false otherwise.
    function isActivated(address account) public view virtual returns (bool);

    function acceptGuardian(address guardian, address account) internal virtual;

    function processRecovery(
        address guardian,
        address account,
        bytes32 recoveryDataHash
    ) internal virtual;

    /// @notice Completes the recovery process.
    /// @dev This function must be implemented by inheriting contracts to finalize the recovery
    /// process.
    /// @param account The address of the account to be recovered.
    /// @param completeCalldata The calldata for the recovery process.
    function completeRecovery(
        address account,
        bytes memory completeCalldata
    ) external virtual;

    /// @notice Computes the address for guardian verifier contract using the CREATE2 opcode.
    /// @dev This function utilizes the `Create2` library to compute the address. The computation
    /// uses a provided account address to be recovered, account salt, and
    /// the hash of the encoded ERC1967Proxy creation code concatenated with the encoded guardian verifier implementation
    /// address and the initialization call data. This ensures that the computed address is
    /// deterministic and unique per account salt.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param account The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The computed address.
    function computeGuardianVerifierAddress(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) public view virtual returns (address) {
        if (
            guardianVerifierImplementation == address(0) ||
            guardianVerifierImplementation.code.length == 0
        ) {
            revert InvalidGuardianImplementation();
        }

        return
            Create2.computeAddress(
                accountSalt,
                keccak256(
                    abi.encodePacked(
                        type(ERC1967Proxy).creationCode,
                        abi.encode(
                            guardianVerifierImplementation,
                            abi.encodeCall(
                                IGuardianVerifier.initialize,
                                (account, accountSalt, verifierInitData)
                            )
                        )
                    )
                )
            );
    }

    /// @notice Deploys a new proxy contract for guardian verification.
    /// @dev This function uses the CREATE2 opcode to deploy a new ERC1967Proxy contract with a
    /// deterministic address.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param account The address of the account to be recovered.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The address of the newly deployed proxy contract.
    function deployGuardianVerifierProxy(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) internal virtual returns (address) {
        if (
            guardianVerifierImplementation == address(0) ||
            guardianVerifierImplementation.code.length == 0
        ) {
            revert InvalidGuardianImplementation();
        }

        ERC1967Proxy proxy = new ERC1967Proxy{salt: accountSalt}(
            guardianVerifierImplementation,
            abi.encodeCall(
                IGuardianVerifier.initialize,
                (account, accountSalt, verifierInitData)
            )
        );
        return address(proxy);
    }

    /// @notice Handles an acceptance by a new guardian.
    /// @dev This function deploys a new guardian verifier contract as a
    /// proxy if validations pass and initializes the contract, finally validates the proof.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param account The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed guardian verifier.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @param proofData The proof data required for the guardian verifier.
    /// the command in the given email auth message.
    function handleAcceptance(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData,
        IGuardianVerifier.ProofData memory proofData
    ) external {
        address guardian = computeGuardianVerifierAddress(
            guardianVerifierImplementation,
            account,
            accountSalt,
            verifierInitData
        );

        if (guardian.code.length == 0) {
            address proxyAddress = deployGuardianVerifierProxy(
                guardianVerifierImplementation,
                account,
                accountSalt,
                verifierInitData
            );

            if (proxyAddress != guardian) {
                revert InvalidProxyDeployment();
            }
        }

        // Nullifier check is handles by the verifier in this case
        bool isVerified = IGuardianVerifier(guardian).verifyProof(
            account,
            proofData
        );

        if (!isVerified) {
            revert ProofVerificationFailed();
        }

        acceptGuardian(guardian, account);
    }

    /// @notice Processes the recovery based on the guardian's proof .
    /// @dev Verify the provided proof for a deployed guardian's verifier contract specifically for recovery.
    /// Requires that the guardian is already deployed
    /// @param guardian The address of the guardian who is processing the recovery request
    /// @param account The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness while deploying the guardian verifier
    /// @param recoveryDataHash The hash of the recovery data
    /// @param proofData The proof data for the guardian verifier.
    function handleRecovery(
        address guardian,
        address account,
        bytes32 accountSalt,
        bytes32 recoveryDataHash,
        IGuardianVerifier.ProofData memory proofData
    ) external {
        if (address(guardian).code.length == 0) {
            revert GuardianNotDeployed();
        }

        // Nullifier check is handles by the verifier in this case
        bool isVerified = IGuardianVerifier(guardian).verifyProof(
            account,
            proofData
        );

        if (!isVerified) {
            revert ProofVerificationFailed();
        }

        processRecovery(guardian, account, recoveryDataHash);
    }
}
