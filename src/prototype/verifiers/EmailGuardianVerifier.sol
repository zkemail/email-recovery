// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {EmailAuth, EmailAuthMsg} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { StringUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/StringUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Create2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { IGuardianVerifier } from "../interfaces/IGuardianVerifier.sol";


contract EmailGuardianVerifier is IGuardianVerifier {
    uint8 constant EMAIL_ACCOUNT_RECOVERY_VERSION_ID = 1;

    address public verifierAddr;
    address public dkimAddr;
    address public emailAuthImplementationAddr;


    error InvalidTemplateIndex(uint256 templateIdx, uint256 expectedTemplateIdx);
    error InvalidCommandParams(uint256 paramsLength, uint256 expectedParamsLength);
    error InvalidAccount();

    constructor(
        address _verifier,
        address _dkimRegistry,
        address _emailAuthImpl
    ){
        verifierAddr = _verifier;
        dkimAddr = _dkimRegistry;
        emailAuthImplementationAddr = _emailAuthImpl;
    }

    /// @notice Returns the address of the verifier contract.
    /// @dev This function is virtual and can be overridden by inheriting contracts.
    /// @return address The address of the verifier contract.

    function verifier() public view virtual returns (address) {
        return verifierAddr;
    }


    /// @notice Returns the address of the DKIM contract.
    /// @dev This function is virtual and can be overridden by inheriting contracts.
    /// @return address The address of the DKIM contract.

    function dkim() public view virtual returns (address) {
        return dkimAddr;
    }

    /// @notice Returns the address of the email auth contract implementation.
    /// @dev This function is virtual and can be overridden by inheriting contracts.
    /// @return address The address of the email authentication contract implementation.

    function emailAuthImplementation() public view virtual returns (address) {
        return emailAuthImplementationAddr;
    }

    function handleAcceptVerification(
        address account,
        address recoveryModule,
        bytes memory guardian,
        bytes memory data
    ) external {
        if(msg.sender != recoveryModule){
            revert CallerDoesNotMatchRecoveryModule(recoveryModule, msg.sender);
        }

        address _guardian = abi.decode(guardian, (address));
        (EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) = abi.decode(data, (EmailAuthMsg, uint256));

        require(account == validateAcceptanceCommand(templateIdx, emailAuthMsg.commandParams));
        require(_guardian == computeEmailAuthAddress(account, emailAuthMsg.proof.accountSalt));
        uint256 templateId = computeAcceptanceTemplateId(templateIdx);

        require(templateId == emailAuthMsg.templateId, "invalid template id");

        require(emailAuthMsg.proof.isCodeExist == true, "isCodeExist is false");

        EmailAuth guardianEmailAuth;
        if (_guardian.code.length == 0) {
            address proxyAddress = deployEmailAuthProxy(
                account,
                emailAuthMsg.proof.accountSalt
            );
            guardianEmailAuth = EmailAuth(proxyAddress);
            guardianEmailAuth.initDKIMRegistry(dkim());
            guardianEmailAuth.initVerifier(verifier());
            for (uint256 idx = 0; idx < acceptanceCommandTemplates().length; idx++) {
                guardianEmailAuth.insertCommandTemplate(
                    computeAcceptanceTemplateId(idx),
                    acceptanceCommandTemplates()[idx]
                );
            }
            for (uint idx = 0; idx < recoveryCommandTemplates().length; idx++) {
                guardianEmailAuth.insertCommandTemplate(
                    computeRecoveryTemplateId(idx),
                    recoveryCommandTemplates()[idx]
                );
            }
        } else {
            guardianEmailAuth = EmailAuth(payable(_guardian));
            require(guardianEmailAuth.controller() == address(this), "invalid controller");

        }

        guardianEmailAuth.authEmail(emailAuthMsg);
    }

    function handleProcessVerification(
        address account,
        address recoveryModule,
        bytes memory guardian,
        bytes memory data
    ) external  returns(bytes32){
        if(msg.sender != recoveryModule){
            revert CallerDoesNotMatchRecoveryModule(recoveryModule, msg.sender);
        }

        address _guardian = abi.decode(guardian, (address));
        (EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) = abi.decode(data, (EmailAuthMsg, uint256));

        require(account == extractRecoveredAccountFromRecoveryCommand(emailAuthMsg.commandParams, templateIdx));
        require(_guardian == computeEmailAuthAddress(account, emailAuthMsg.proof.accountSalt));

        // Check if the guardian is deployed
        require(_guardian.code.length > 0, "guardian is not deployed");

        uint256 templateId = computeRecoveryTemplateId(templateIdx);
        require(templateId == emailAuthMsg.templateId, "invalid template id");

        EmailAuth guardianEmailAuth = EmailAuth(payable(_guardian));

        guardianEmailAuth.authEmail(emailAuthMsg);

        return parseRecoveryDataHash(templateIdx, emailAuthMsg.commandParams);
    }

    /**
     * @notice Extracts the account address to be recovered from the command parameters of a
     * recovery email.
     * @param commandParams The command parameters of the recovery email.
     * @param {templateIdx} Unused parameter. The index of the template used for the recovery
     * request
     */
    function extractRecoveredAccountFromRecoveryCommand(
        bytes[] memory commandParams,
        uint256 /* templateIdx */
    )
        public
        pure
        returns (address)
    {
        return abi.decode(commandParams[0], (address));
    }

   /**
     * @notice Validates the command params for an acceptance email
     * @param templateIdx The index of the template used for acceptance
     * @param commandParams The command parameters of the acceptance email.
     * @return accountInEmail The account address in the acceptance email
     */
    function validateAcceptanceCommand(
        uint256 templateIdx,
        bytes[] memory commandParams
    )
        public
        pure
        returns (address)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        if (commandParams.length != 1) {
            revert InvalidCommandParams(commandParams.length, 1);
        }

        // The GuardianStatus check in acceptGuardian implicitly
        // validates the account, so no need to re-validate here
        address accountInEmail = abi.decode(commandParams[0], (address));

        return accountInEmail;
    }

    /**
     * @notice Returns a hard-coded two-dimensional array of strings representing the command
     * templates for an acceptance by a new guardian.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function acceptanceCommandTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](5);
        templates[0][0] = "Accept";
        templates[0][1] = "guardian";
        templates[0][2] = "request";
        templates[0][3] = "for";
        templates[0][4] = "{ethAddr}";
        return templates;
    }

    /**
     * @notice Returns a hard-coded two-dimensional array of strings representing the command
     * templates for email recovery.
     * @return string[][] A two-dimensional array of strings, where each inner array represents a
     * set of fixed strings and matchers for a command template.
     */
    function recoveryCommandTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](7);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "using";
        templates[0][4] = "recovery";
        templates[0][5] = "hash";
        templates[0][6] = "{string}";
        return templates;
    }

     /**
     * @notice parses the recovery data hash from the command params. The data hash is
     * verified against later when recovery is executed
     * @dev recoveryDataHash = keccak256(abi.encode(validatorOrAccount, recoveryFunctionCalldata))
     * @param templateIdx The index of the template used for the recovery request
     * @param commandParams The command parameters of the recovery email
     * @return recoveryDataHash The keccak256 hash of the recovery data
     */
    function parseRecoveryDataHash(
        uint256 templateIdx,
        bytes[] memory commandParams
    )
        public
        pure
        returns (bytes32)
    {
        if (templateIdx != 0) {
            revert InvalidTemplateIndex(templateIdx, 0);
        }
        return StringUtils.hexToBytes32(abi.decode(commandParams[1], (string)));
    }

    /// @notice Calculates a unique command template ID for an acceptance command template using its index.
    /// @dev Encodes the email account recovery version ID, "ACCEPTANCE", and the template index,
    /// then uses keccak256 to hash these values into a uint ID.
    /// @param templateIdx The index of the acceptance command template.
    /// @return uint The computed uint ID.

    function computeAcceptanceTemplateId(
        uint templateIdx
    ) public pure returns (uint) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        EMAIL_ACCOUNT_RECOVERY_VERSION_ID,
                        "ACCEPTANCE",
                        templateIdx
                    )
                )
            );
    }


    /// @notice Calculates a unique ID for a recovery command template using its index.
    /// @dev Encodes the email account recovery version ID, "RECOVERY", and the template index,
    /// then uses keccak256 to hash these values into a uint256 ID.
    /// @param templateIdx The index of the recovery command template.
    /// @return uint The computed uint ID.

    function computeRecoveryTemplateId(
        uint templateIdx
    ) public pure returns (uint) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        EMAIL_ACCOUNT_RECOVERY_VERSION_ID,
                        "RECOVERY",
                        templateIdx
                    )
                )
            );
    }

    /// @notice Computes the address for email auth contract using the CREATE2 opcode.
    /// @dev This function utilizes the `Create2` library to compute the address. The computation uses a provided account address to be recovered, account salt,
    /// and the hash of the encoded ERC1967Proxy creation code concatenated with the encoded email auth contract implementation
    /// address and the initialization call data. This ensures that the computed address is deterministic and unique per account salt.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value defined as a hash of the guardian's email address and an account code. This is assumed to be unique to a pair of the guardian's email address and the wallet address to be recovered.
    /// @return address The computed address.

    function computeEmailAuthAddress(
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
                            emailAuthImplementation(),
                            abi.encodeCall(
                                EmailAuth.initialize,
                                (recoveredAccount, accountSalt, address(this))
                            )
                        )
                    )
                )
            );
    }


    /// @notice Deploys a new proxy contract for email authentication.
    /// @dev This function uses the CREATE2 opcode to deploy a new ERC1967Proxy contract with a deterministic address.
    /// @param recoveredAccount The address of the account to be recovered.
    /// @param accountSalt A bytes32 salt value used to ensure the uniqueness of the deployed proxy address.
    /// @return address The address of the newly deployed proxy contract.

    function deployEmailAuthProxy(
        address recoveredAccount,
        bytes32 accountSalt

    ) internal virtual returns (address) {
        ERC1967Proxy proxy = new ERC1967Proxy{salt: accountSalt}(
            emailAuthImplementation(),
            abi.encodeCall(
                EmailAuth.initialize,
                (recoveredAccount, accountSalt, address(this))
            )
        );
        return address(proxy);
    }
}