// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RecoveryModuleBase} from "./RecoveryModuleBase.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {ExecutionLib} from "erc7579/lib/ExecutionLib.sol";
import {ModeLib} from "erc7579/lib/ModeLib.sol";

interface ISafe {
    function getOwners() external view returns (address[] memory);
}

contract SafeRecoveryModule is RecoveryModuleBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    mapping(address => bytes) public recoveryData;

    constructor(address _recoveryModule) RecoveryModuleBase(_recoveryModule) {}

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        recoveryData[msg.sender] = data;
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

    function recover(bytes memory data) external {
        (address account, address newOwner, address oldOwner) = abi.decode(
            data,
            (address, address, address)
        );
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
