// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

/**
 * @notice NOT FOR USE IN PRODUCTION
 */
contract OwnableValidator is ERC7579ValidatorBase {
    using SignatureCheckerLib for address;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address subAccout => address owner) public owners;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        if (data.length == 0) return;
        (address owner) = abi.decode(data, (address));
        owners[msg.sender] = owner;
    }

    /**
     * An attacker could overcome authorized timelock by uninstalling and installing the module
     * again
     */
    function onUninstall(bytes calldata) external override {
        delete owners[msg.sender];
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return owners[smartAccount] != address(0);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        view
        override
        returns (ValidationData)
    {
        bool validSig = owners[userOp.sender].isValidSignatureNow(
            ECDSA.toEthSignedMessageHash(userOpHash), userOp.signature
        );
        return _packValidationData(!validSig, type(uint48).max, 0);
    }

    function isValidSignatureWithSender(
        address,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        override
        returns (bytes4)
    {
        address owner = owners[msg.sender];
        return SignatureCheckerLib.isValidSignatureNowCalldata(owner, hash, data)
            ? EIP1271_SUCCESS
            : EIP1271_FAILED;
    }

    function validateSignatureWithData(
        bytes32 hash,
        bytes calldata signature,
        bytes calldata data
    )
        external
        view
        override
        returns (bool)
    {
        return false;
    }

    function changeOwner(address newOwner) external {
        owners[msg.sender] = newOwner;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    function name() external pure returns (string memory) {
        return "OwnableValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
