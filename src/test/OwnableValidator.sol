// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.25;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract OwnableValidator is ERC7579ValidatorBase {
    using SignatureCheckerLib for address;

    /*//////////////////////////////////////////////////////////////////////////
                            CONSTANTS & STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    error NotAuthorized();

    mapping(address subAccout => address owner) public owners;

    /**
     * account to authorized account to authorization
     */
    mapping(address => mapping(address => bool)) public authorized;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    function onInstall(bytes calldata data) external override {
        if (data.length == 0) return;
        (address owner, address authorizedAccount) = abi.decode(data, (address, address));
        owners[msg.sender] = owner;
        authorized[msg.sender][authorizedAccount] = true;
    }

    /**
     * An attacker could overcome authorized timelock by uninstalling and installing the module
     * again
     */
    function onUninstall(bytes calldata) external override {
        delete owners[msg.sender];
        // delete authorized[msg.sender][authorizedAccount];
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

    function changeOwner(
        address account,
        address authorizedAccount,
        address newOwner
    )
        external
        onlyAuthorized(authorizedAccount)
    {
        owners[account] = newOwner;
    }

    /**
     * @notice Adds special permissions for an account to execute priviliged actions
     * on the module, notably changing the owner. This is useful for adding a recovery module.
     * @dev in order for this function to remain secure, the delay time must be longer than
     * the time it takes to authorize an action from the calling account. For example, if there
     * is a recovery delay of 1 day on a recovery module to protect against malicious guardians,
     * the delay for this function must be longer than that time so that an attacker could not
     * authorize itself before the recovery attempt succeeds.
     */
    function authorizeAccount(address accountToAuthorize) public {
        authorized[msg.sender][accountToAuthorize] = true;
    }

    modifier onlyAuthorized(address account) {
        if (authorized[msg.sender][account] == false) revert NotAuthorized();
        _;
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
