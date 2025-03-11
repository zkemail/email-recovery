// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IGuardianVerifier} from "./IGuardianVerifier.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @title Email Account Recovery Contract
/// @notice Provides mechanisms for email-based account recovery, leveraging guardians and
/// template-based email verification.
/// @dev This contract is abstract and requires implementation of several methods for configuring a
/// new guardian and recovering an account contract.
abstract contract EmailAccountRecovery {
    uint8 public constant EMAIL_ACCOUNT_RECOVERY_VERSION_ID = 2;
    address public guardianVerifierImplementation;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ERRORS                                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InvalidGuardianAddress();
    error GuardianNotDeployed();

    error ProofVerificationFailed(string);

    /// @notice Returns the address of the verifier contract.
    /// @dev This function is virtual and can be overridden by inheriting contracts.
    /// @return address The address of the verifier contract.
    function guardianVerifierImplementationAddress()
        public
        view
        virtual
        returns (address)
    {
        return guardianVerifierImplementation;
    }

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
    /// uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded email
    /// auth contract implementation
    /// address and the initialization call data. This ensures that the computed address is
    /// deterministic and unique per account salt.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @return address The computed address.
    function computeGuardianVerifierAddress(
        address recoveredAccount,
        bytes32 accountSalt
    ) public view virtual returns (address) {
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
                                (recoveredAccount, accountSalt, address(this))
                            )
                        )
                    )
                )
            );
    }

    /// @notice Deploys a new proxy contract for guardian verification.
    /// @dev This function uses the CREATE2 opcode to deploy a new ERC1967Proxy contract with a
    /// deterministic address.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @return address The address of the newly deployed proxy contract.
    function deployGuardianVerifierProxy(
        address recoveredAccount,
        bytes32 accountSalt
    ) internal virtual returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy{salt: accountSalt}(
            guardianVerifierImplementation,
            abi.encodeCall(
                IGuardianVerifier.initialize,
                (recoveredAccount, accountSalt, address(this))
            )
        );
        return address(proxy);
    }

    /// @notice Handles an acceptance by a new guardian.
    /// @dev This function validates the email auth message, deploys a new EmailAuth contract as a
    /// proxy if validations pass and initializes the contract.
    //  /// @param emailAuthMsg The email auth message for the email send from the guardian.
    //  /// @param templateIdx The index of the command template for acceptance, which should match with
    /// the command in the given email auth message.
    function handleAcceptance(
        address recoveredAccount,
        bytes32 accountSalt,
        bytes memory verifierInitData,
        IGuardianVerifier.ProofData memory proofData
    ) external {
        address guardian = computeGuardianVerifierAddress(
            recoveredAccount,
            accountSalt
        );

        if (guardian.code.length == 0) {
            address proxyAddress = deployGuardianVerifierProxy(
                recoveredAccount,
                accountSalt
            );

            if (proxyAddress != guardian) {
                revert InvalidGuardianAddress();
            }

            IGuardianVerifier(guardian).initVerifier(
                recoveredAccount,
                verifierInitData
            );
        }

        // TODO: Do we need this check still ?
        //     guardianEmailAuth = EmailAuth(payable(address(guardian)));
        //     require(
        //         guardianEmailAuth.controller() == address(this),
        //         "invalid controller"
        //     );

        (bool isVerified, string memory err) = IGuardianVerifier(guardian)
            .verifyProof(recoveredAccount, proofData);

        if (!isVerified) {
            revert ProofVerificationFailed(err);
        }

        acceptGuardian(guardian, recoveredAccount);
    }

    /// @notice Processes the recovery based on an email from the guardian.
    /// @dev Verify the provided email auth message for a deployed guardian's EmailAuth contract and
    /// a specific command template for recovery.
    /// Requires that the guardian is already deployed, and the template ID corresponds to the
    /// `templateId` in the given email auth message. Once validated.
    /// @param proofData The proof data for the guardian verifier.
    function handleRecovery(
        address recoveredAccount,
        bytes32 accountSalt,
        bytes32 recoveryDataHash,
        IGuardianVerifier.ProofData memory proofData
    ) external {
        address guardian = computeGuardianVerifierAddress(
            recoveredAccount,
            accountSalt
        );

        // Check if the guardian is deployed
        if (address(guardian).code.length == 0) {
            revert GuardianNotDeployed();
        }

        // TODO: Migration
        // address recoveredAccount = extractRecoveredAccountFromRecoveryCommand(
        //     emailAuthMsg.commandParams,
        //     templateIdx
        // );
        // require(recoveredAccount != address(0), "invalid account in email");
        // address guardian = computeEmailAuthAddress(
        //     recoveredAccount,
        //     emailAuthMsg.proof.accountSalt
        // );

        // uint256 templateId = uint256(
        //     keccak256(
        //         abi.encode(
        //             EMAIL_ACCOUNT_RECOVERY_VERSION_ID,
        //             "RECOVERY",
        //             templateIdx
        //         )
        //     )
        // );
        // require(templateId == emailAuthMsg.templateId, "invalid template id");

        (bool isVerified, string memory err) = IGuardianVerifier(guardian)
            .verifyProof(recoveredAccount, proofData);

        if (!isVerified) {
            revert ProofVerificationFailed(err);
        }

        processRecovery(guardian, recoveredAccount, recoveryDataHash);
    }
}
