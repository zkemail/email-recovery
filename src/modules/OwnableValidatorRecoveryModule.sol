// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RecoveryModuleBase} from "./RecoveryModuleBase.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import "forge-std/console2.sol";

contract OwnableValidatorRecoveryModule is RecoveryModuleBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    error InvalidNewOwner();

    mapping(address => address) public validators;

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
        address validator = abi.decode(data, (address));

        validators[msg.sender] = validator;
    }

    /**
     * De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {
        delete validators[msg.sender];
    }

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
    ) external override onlyRecovery {
        address newOwner = abi.decode(subjectParams[1], (address));
        if (newOwner == address(0)) {
            revert InvalidNewOwner();
        }
        bytes memory encodedCall = abi.encodeWithSignature(
            "changeOwner(address,address,address)",
            account,
            address(this),
            newOwner
        );

        _execute(account, validators[account], 0, encodedCall);
    }

    modifier onlyRecovery() {
        if (msg.sender != zkEmailRecovery) revert NotAuthorizedToRecover();
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure override returns (string memory) {
        return "OwnableValidatorRecoveryModule";
    }

    /**
     * The version of the module
     * @return version The version of the module
     */
    function version() external pure override returns (string memory) {
        return "0.0.1";
    }
}
