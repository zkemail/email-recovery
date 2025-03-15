// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IGuardianVerifier} from "./interfaces/IGuardianVerifier.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Email Account Recovery Contract
/// @notice Provides mechanisms for email-based account recovery, leveraging guardians and
/// template-based email verification.
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
    error ProofVerificationFailed(string);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Functions                               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Returns if the account to be recovered has already activated the controller (this
    /// contract).
    /// @dev This function is virtual and should be implemented by inheriting contracts.
    /// @dev This function helps a relayer inactivate the guardians' data after the account
    /// inactivates the controller (this contract).
    /// @param recoveredAccount The address of the account to be recovered.
    /// @return bool True if the account is already activated, false otherwise.
    function isActivated(
        address recoveredAccount
    ) public view virtual returns (bool);

    function acceptGuardian(
        address guardian,
        address recoveredAccount
    ) internal virtual;

    function processRecovery(
        address guardian,
        address recoveredAccount,
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
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The computed address.
    function computeGuardianVerifierAddress(
        address guardianVerifierImplementation,
        address recoveredAccount,
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
                                (
                                    recoveredAccount,
                                    accountSalt,
                                    verifierInitData
                                )
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
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @return address The address of the newly deployed proxy contract.
    function deployGuardianVerifierProxy(
        address guardianVerifierImplementation,
        address recoveredAccount,
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
                (recoveredAccount, accountSalt, verifierInitData)
            )
        );
        return address(proxy);
    }

    /// @notice Handles an acceptance by a new guardian.
    /// @dev This function validates the email auth message, deploys a new EmailAuth contract as a
    /// proxy if validations pass and initializes the contract.
    /// @param guardianVerifierImplementation The address of the guardian verifier implementation.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed guardian verifier.
    /// @param verifierInitData The initialization data for the guardian verifier.
    /// @param proofData The proof data required for the guardian verifier.
    /// the command in the given email auth message.
    function handleAcceptance(
        address guardianVerifierImplementation,
        address recoveredAccount,
        bytes32 accountSalt,
        bytes memory verifierInitData,
        IGuardianVerifier.ProofData memory proofData
    ) external {
        address guardian = computeGuardianVerifierAddress(
            guardianVerifierImplementation,
            recoveredAccount,
            accountSalt,
            verifierInitData
        );

        if (guardian.code.length == 0) {
            address proxyAddress = deployGuardianVerifierProxy(
                guardianVerifierImplementation,
                recoveredAccount,
                accountSalt,
                verifierInitData
            );

            if (proxyAddress != guardian) {
                revert InvalidProxyDeployment();
            }
        }

        bool isVerified = IGuardianVerifier(guardian).verifyProofStrict(
            recoveredAccount,
            proofData
        );

        acceptGuardian(guardian, recoveredAccount);
    }

    /// @notice Processes the recovery based on an email from the guardian.
    /// @dev Verify the provided email auth message for a deployed guardian's EmailAuth contract and
    /// a specific command template for recovery.
    /// Requires that the guardian is already deployed
    /// @param guardian The address of the guardian who is processing the recovery request
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness while deploying the guardian verifier
    /// @param recoveryDataHash The hash of the recovery data
    /// @param proofData The proof data for the guardian verifier.
    function handleRecovery(
        address guardian,
        address recoveredAccount,
        bytes32 accountSalt,
        bytes32 recoveryDataHash,
        IGuardianVerifier.ProofData memory proofData
    ) external {
        // TODO: Do we need to compute the guardian in handleRecovery as well, or just take the address as an input
        // address guardian = computeGuardianVerifierAddress(
        //     guardianVerifierImplementation,
        //     recoveredAccount,
        //     accountSalt,
        //     verifierInitData
        // );

        if (address(guardian).code.length == 0) {
            revert GuardianNotDeployed();
        }

        bool isVerified = IGuardianVerifier(guardian).verifyProofStrict(
            recoveredAccount,
            proofData
        );

        processRecovery(guardian, recoveredAccount, recoveryDataHash);
    }
}
