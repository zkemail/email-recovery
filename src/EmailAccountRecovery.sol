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
    uint8 constant EMAIL_ACCOUNT_RECOVERY_VERSION_ID = 1;
    address public guardianVerifierImplementation;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    ERRORS                                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    error InvalidGuardianAddress();
    error GuardianNotDeployed();

    // /// @notice Returns the address of the verifier contract.
    // /// @dev This function is virtual and can be overridden by inheriting contracts.
    // /// @return address The address of the verifier contract.
    // function verifier() public view virtual returns (address) {
    //     return verifierAddr;
    // }

    // /// @notice Returns the address of the verifier contract.
    // /// @dev This function is virtual and can be overridden by inheriting contracts.
    // /// @return address The address of the verifier contract.
    // function verifier() public view virtual returns (address) {
    //     return verifierAddr;
    // }

    // /// @notice Returns the address of the DKIM contract.
    // /// @dev This function is virtual and can be overridden by inheriting contracts.
    // /// @return address The address of the DKIM contract.
    // function dkim() public view virtual returns (address) {
    //     return dkimAddr;
    // }

    // /// @notice Returns the address of the email auth contract implementation.
    // /// @dev This function is virtual and can be overridden by inheriting contracts.
    // /// @return address The address of the email authentication contract implementation.
    // function emailAuthImplementation() public view virtual returns (address) {
    //     return emailAuthImplementationAddr;
    // }

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

    // /// @notice Returns a two-dimensional array of strings representing the command templates for an
    // /// acceptance by a new guardian's.
    // /// @dev This function is virtual and should be implemented by inheriting contracts to define
    // /// specific acceptance command templates.
    // /// @return string[][] A two-dimensional array of strings, where each inner array represents a
    // /// set of fixed strings and matchers for a command template.
    // function acceptanceCommandTemplates()
    //     public
    //     view
    //     virtual
    //     returns (string[][] memory);

    // /// @notice Returns a two-dimensional array of strings representing the command templates for
    // /// email recovery.
    // /// @dev This function is virtual and should be implemented by inheriting contracts to define
    // /// specific recovery command templates.
    // /// @return string[][] A two-dimensional array of strings, where each inner array represents a
    // /// set of fixed strings and matchers for a command template.
    // function recoveryCommandTemplates()
    //     public
    //     view
    //     virtual
    //     returns (string[][] memory);

    // /// @notice Extracts the account address to be recovered from the command parameters of an
    // /// acceptance email.
    // /// @dev This function is virtual and should be implemented by inheriting contracts to extract
    // /// the account address from the command parameters.
    // /// @param commandParams The command parameters of the acceptance email.
    // /// @param templateIdx The index of the acceptance command template.
    // function extractRecoveredAccountFromAcceptanceCommand(
    //     bytes[] memory commandParams,
    //     uint256 templateIdx
    // ) public view virtual returns (address);

    // /// @notice Extracts the account address to be recovered from the command parameters of a
    // /// recovery email.
    // /// @dev This function is virtual and should be implemented by inheriting contracts to extract
    // /// the account address from the command parameters.
    // /// @param commandParams The command parameters of the recovery email.
    // /// @param templateIdx The index of the recovery command template.
    // function extractRecoveredAccountFromRecoveryCommand(
    //     bytes[] memory commandParams,
    //     uint256 templateIdx
    // ) public view virtual returns (address);

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
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @return address The computed address.
    function computeGuardianVerifierAddress(
        bytes32 accountSalt,
        address recoveredAccount
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
                                (recoveredAccount, address(this))
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
        bytes32 accountSalt,
        address recoveredAccount
    ) internal virtual returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy{salt: accountSalt}(
            guardianVerifierImplementation,
            abi.encodeCall(
                IGuardianVerifier.initialize,
                (recoveredAccount, address(this))
            )
        );
        return address(proxy);
    }

    // /// @notice Calculates a unique command template ID for an acceptance command template using its
    // /// index.
    // /// @dev Encodes the email account recovery version ID, "ACCEPTANCE", and the template index,
    // /// then uses keccak256 to hash these values into a uint ID.
    // /// @param templateIdx The index of the acceptance command template.
    // /// @return uint The computed uint ID.
    // function computeAcceptanceTemplateId(
    //     uint256 templateIdx
    // ) public pure returns (uint256) {
    //     return
    //         uint256(
    //             keccak256(
    //                 abi.encode(
    //                     EMAIL_ACCOUNT_RECOVERY_VERSION_ID,
    //                     "ACCEPTANCE",
    //                     templateIdx
    //                 )
    //             )
    //         );
    // }

    // /// @notice Calculates a unique ID for a recovery command template using its index.
    // /// @dev Encodes the email account recovery version ID, "RECOVERY", and the template index,
    // /// then uses keccak256 to hash these values into a uint256 ID.
    // /// @param templateIdx The index of the recovery command template.
    // /// @return uint The computed uint ID.
    // function computeRecoveryTemplateId(
    //     uint256 templateIdx
    // ) public pure returns (uint256) {
    //     return
    //         uint256(
    //             keccak256(
    //                 abi.encode(
    //                     EMAIL_ACCOUNT_RECOVERY_VERSION_ID,
    //                     "RECOVERY",
    //                     templateIdx
    //                 )
    //             )
    //         );
    // }

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
        // address recoveredAccount = extractRecoveredAccountFromAcceptanceCommand(
        //     emailAuthMsg.commandParams,
        //     templateIdx
        // );
        // require(recoveredAccount != address(0), "invalid account in email");
        // address guardian = computeEmailAuthAddress(
        //     recoveredAccount,
        //     emailAuthMsg.proof.accountSalt
        // );
        // uint256 templateId = computeAcceptanceTemplateId(templateIdx);
        // require(templateId == emailAuthMsg.templateId, "invalid template id");
        // require(emailAuthMsg.proof.isCodeExist == true, "isCodeExist is false");

        address guardian = computeGuardianVerifierAddress(
            accountSalt,
            recoveredAccount
        );

        if (guardian.code.length == 0) {
            address proxyAddress = deployGuardianVerifierProxy(
                accountSalt,
                recoveredAccount
            );

            if (proxyAddress != guardian) {
                revert InvalidGuardianAddress();
            }

            IGuardianVerifier(guardian).initVerifier(
                recoveredAccount,
                verifierInitData
            );
        }

        // EmailAuth guardianEmailAuth;
        // if (guardian.code.length == 0) {
        //     address proxyAddress = deployEmailAuthProxy(
        //         recoveredAccount,
        //         emailAuthMsg.proof.accountSalt
        //     );
        //     guardianEmailAuth = EmailAuth(proxyAddress);
        //     guardianEmailAuth.initDKIMRegistry(dkim());
        //     guardianEmailAuth.initVerifier(verifier());
        //     for (
        //         uint256 idx = 0;
        //         idx < acceptanceCommandTemplates().length;
        //         idx++
        //     ) {
        //         guardianEmailAuth.insertCommandTemplate(
        //             computeAcceptanceTemplateId(idx),
        //             acceptanceCommandTemplates()[idx]
        //         );
        //     }
        //     for (
        //         uint256 idx = 0;
        //         idx < recoveryCommandTemplates().length;
        //         idx++
        //     ) {
        //         guardianEmailAuth.insertCommandTemplate(
        //             computeRecoveryTemplateId(idx),
        //             recoveryCommandTemplates()[idx]
        //         );
        //     }
        // } else {
        //     guardianEmailAuth = EmailAuth(payable(address(guardian)));
        //     require(
        //         guardianEmailAuth.controller() == address(this),
        //         "invalid controller"
        //     );
        // }
        // An assertion to confirm that the authEmail function is executed successfully
        // and does not return an error.
        // guardianEmailAuth.authEmail(emailAuthMsg);

        IGuardianVerifier(guardian).verifyProof(recoveredAccount, proofData);
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
            accountSalt,
            recoveredAccount
        );

        // Check if the guardian is deployed
        if (address(guardian).code.length == 0) {
            revert GuardianNotDeployed();
        }

        // address recoveredAccount = extractRecoveredAccountFromRecoveryCommand(
        //     emailAuthMsg.commandParams,
        //     templateIdx
        // );
        // require(recoveredAccount != address(0), "invalid account in email");
        // address guardian = computeEmailAuthAddress(
        //     recoveredAccount,
        //     emailAuthMsg.proof.accountSalt
        // );
        // // Check if the guardian is deployed
        // require(address(guardian).code.length > 0, "guardian is not deployed");
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

        // EmailAuth guardianEmailAuth = EmailAuth(payable(address(guardian)));

        // // An assertion to confirm that the authEmail function is executed successfully
        // // and does not return an error.
        // guardianEmailAuth.authEmail(emailAuthMsg);

        IGuardianVerifier(guardian).verifyProof(recoveredAccount, proofData);

        processRecovery(guardian, recoveredAccount, recoveryDataHash);
    }
}
