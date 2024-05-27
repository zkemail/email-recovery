// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {ExecutionLib} from "erc7579/lib/ExecutionLib.sol";
import {ModeLib} from "erc7579/lib/ModeLib.sol";
import {EmailAuth} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {RecoveryModuleBase} from "./RecoveryModuleBase.sol";
import {IZkEmailRecovery} from "../interfaces/IZkEmailRecovery.sol";

interface ISafe {
    function getOwners() external view returns (address[] memory);
}

contract SafeRecoveryModule is RecoveryModuleBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/
    error NotTrustedRecoveryContract();
    error InvalidOldOwner();
    error InvalidNewOwner();

    constructor(
        address _zkEmailRecovery
    ) RecoveryModuleBase(_zkEmailRecovery) {}

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        (
            address[] memory guardians,
            uint256[] memory weights,
            uint256 threshold,
            uint256 delay,
            uint256 expiry
        ) = abi.decode(data, (address[], uint256[], uint256, uint256, uint256));

        bytes memory encodedCall = abi.encodeWithSignature(
            "configureRecovery(address[],uint256[],uint256,uint256,uint256)",
            guardians,
            weights,
            threshold,
            delay,
            expiry
        );

        _execute(msg.sender, zkEmailRecovery, 0, encodedCall);
    }

    /**
     * De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {}

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(
        address smartAccount
    ) external view override returns (bool) {
        return false;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function recover(
        address account,
        bytes[] memory subjectParams
    ) external override {
        if (msg.sender != zkEmailRecovery) {
            revert NotTrustedRecoveryContract();
        }

        address oldOwner = abi.decode(subjectParams[1], (address));
        address newOwner = abi.decode(subjectParams[2], (address));
        if (oldOwner == address(0)) {
            revert InvalidOldOwner();
        }
        if (newOwner == address(0)) {
            revert InvalidNewOwner();
        }

        address previousOwnerInLinkedList = getPreviousOwnerInLinkedList(
            account,
            oldOwner
        );
        bytes memory encodedSwapOwnerCall = abi.encodeWithSignature(
            "swapOwner(address,address,address)",
            previousOwnerInLinkedList,
            oldOwner,
            newOwner
        );
        IERC7579Account(account).executeFromExecutor(
            ModeLib.encodeSimpleSingle(),
            ExecutionLib.encodeSingle(account, 0, encodedSwapOwnerCall)
        );
    }

    /**
     * @notice Helper function that retrieves the owner that points to the owner to be
     * replaced in the Safe `owners` linked list. Based on the logic used to swap
     * owners in the safe core sdk.
     * @param safe the safe account to query
     * @param oldOwner the old owner to be swapped in the recovery attempt.
     */
    function getPreviousOwnerInLinkedList(
        address safe,
        address oldOwner
    ) internal view returns (address) {
        address[] memory owners = ISafe(safe).getOwners();

        uint256 oldOwnerIndex;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == oldOwner) {
                oldOwnerIndex = i;
                break;
            }
        }
        address sentinelOwner = address(0x1);
        return oldOwnerIndex == 0 ? sentinelOwner : owners[oldOwnerIndex - 1];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure override returns (string memory) {
        return "SafeRecoveryModule";
    }

    /**
     * The version of the module
     * @return version The version of the module
     */
    function version() external pure override returns (string memory) {
        return "0.0.1";
    }
}
