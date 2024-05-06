// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {RecoveryModuleBase} from "./RecoveryModuleBase.sol";

contract OwnableValidatorRecoveryModule is RecoveryModuleBase {
    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    struct RecoveryData {
        address newOwner;
        address validator;
    }

    mapping(address => RecoveryData) public recoveryData;

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
        (address newOwner, address validator) = abi.decode(
            data,
            (address, address)
        );

        recoveryData[msg.sender] = RecoveryData(newOwner, validator);
    }

    /**
     * De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata data) external override {
        delete recoveryData[msg.sender];
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

    function getRecoveryData(
        address account
    ) public returns (RecoveryData memory) {
        return recoveryData[account];
    }

    function recover(bytes memory data) external override onlyRecovery {
        address account = abi.decode(data, (address));

        RecoveryData memory recoveryData = getRecoveryData(account);

        bytes memory encodedCall = abi.encodeWithSignature(
            "changeOwner(address,address,address)",
            account,
            address(this),
            recoveryData.newOwner
        );

        _execute(account, recoveryData.validator, 0, encodedCall);
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
