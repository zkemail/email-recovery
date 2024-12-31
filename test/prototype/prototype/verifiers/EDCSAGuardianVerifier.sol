// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {SignatureCheckerLib} from "solady/utils/SignatureCheckerLib.sol";
import { IGuardianVerifier } from "../interfaces/IGuardianVerifier.sol";


contract ECDSAGuardianVerifier is IGuardianVerifier {
    bytes32 private constant _HANDLE_TYPEHASH = keccak256("HandleMessage(bytes32 hash, uint256 nonce)");
    
    mapping(address account => mapping(address recoveryModule => mapping(address guardian => uint64 nonce))) guardianNonce;

    error InvalidSignature(address signer, bytes signature);

    /**
     * @notice Handles the acceptance of a guardian by verifying the signature of the guardian.
     * @dev Can only be called by the provided recovery module.
     * @param account The account for which the guardian is being accepted.
     * @param recoveryModule The recovery module that is accepting the guardian.
     * @param guardian The guardian being accepted.
     * @param data The acceptance verification data.
     */
    function handleAcceptVerification(
        address account,
        address recoveryModule,
        bytes memory guardian,
        bytes memory data
    ) external  {
        if(msg.sender != recoveryModule){
            revert CallerDoesNotMatchRecoveryModule(recoveryModule, msg.sender);
        }
        address _guardian = abi.decode(guardian, (address));
        bytes32 acceptanceMsgHash = keccak256(
            bytes(
                string.concat(
                    "Accept Guardian for account: ", 
                    Strings.toHexString(uint256(uint160(account)), 20), 
                    " using ", 
                    Strings.toHexString(uint256(uint160(recoveryModule)), 20)
                )
            )
        );
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                _hashStruct(acceptanceMsgHash, guardianNonce[account][recoveryModule][_guardian]++)
            )
        );
        if(!SignatureCheckerLib.isValidSignatureNow(_guardian, digest, data)) revert InvalidSignature(_guardian, data);
    }


    /**
     * @notice Handles the processing of a guardian during recovery by verifying the signature of the guardian.
     * @dev Can only be called by the provided recovery module.
     * @param account The account for which the guardian is being processed to vote/initiate a recovery.
     * @param recoveryModule The recovery module that is processing the guardian.
     * @param guardian The guardian being processed.
     * @param data The processing verification data.
     * @return The hash of the recovery data.
     */
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
        (bytes32 recoveryDataHash, bytes memory signatureData) = abi.decode(data, (bytes32, bytes));
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator(),
                _hashStruct(recoveryDataHash, guardianNonce[account][recoveryModule][_guardian]++)
            )
        );
        if(!SignatureCheckerLib.isValidSignatureNow(_guardian, digest, signatureData)) revert InvalidSignature(_guardian, data);
        return recoveryDataHash;
    }

    function _hashStruct(bytes32 msgHash, uint64 nonce) internal pure returns(bytes32){
        return keccak256(abi.encode(_HANDLE_TYPEHASH, msgHash, nonce));
    }

    /// @notice Returns the `domainSeparator` used to create EIP-712 compliant hashes.
    ///
    /// @dev Implements domainSeparator = hashStruct(eip712Domain).
    ///      See https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator.
    ///
    /// @return The 32 bytes domain separator result.
    function domainSeparator() public view returns (bytes32) {
        (string memory name, string memory version) = _domainNameAndVersion();
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                block.chainid,
                address(this)
            )
        );
    }

    function _domainNameAndVersion() internal pure returns (string memory, string memory) {
        return ("ECDSA Guardian Verifier", "1.0.0");
    }

}