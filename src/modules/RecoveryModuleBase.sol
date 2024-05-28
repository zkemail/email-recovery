// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ERC7579ExecutorBase} from "@rhinestone/modulekit/src/Modules.sol";

abstract contract RecoveryModuleBase is ERC7579ExecutorBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    address public immutable zkEmailRecovery;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external virtual {}

    /**
     * De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external virtual {}

    /**
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(
        address smartAccount
    ) external view virtual returns (bool) {}

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function recover(
        address account,
        bytes[] memory subjectParams
    ) external virtual {}

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure virtual returns (string memory) {}

    /**
     * The version of the module
     * @return version The version of the module
     */
    function version() external pure virtual returns (string memory) {}

    /**
     * Check if the module is of a certain type
     * @param typeID The type ID to check
     * @return true if the module is of the given type, false otherwise
     */
    function isModuleType(uint256 typeID) external pure returns (bool) {
        return typeID == TYPE_EXECUTOR;
    }
}
