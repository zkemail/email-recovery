// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ISafe } from "../interfaces/ISafe.sol";
import { Enum } from "@safe-global/safe-contracts/contracts/common/Enum.sol";

/**
 * A safe module that recovers a safe owner via ZK Email
 */
contract SafeEmailRecoveryModule {
    bytes4 public constant selector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

    /**
     * Trusted email recovery manager contract that handles recovery requests
     */
    address public immutable emailRecoveryManager;

    event RecoveryExecuted(address indexed account);

    error ModuleEnabledCheckFailed(address account, address module);
    error NotTrustedRecoveryManager();
    error InvalidSelector(bytes4 selector);
    error RecoveryFailed(address account);

    constructor(address _emailRecoveryManager) {
        emailRecoveryManager = _emailRecoveryManager;
    }

    /**
     * Check if the recovery module is authorized to recover the account
     * @param account The smart account to check
     * @return true if the module is authorized, false otherwise
     */
    function isAuthorizedToRecover(address account) external returns (bool) {
        (bool success, bytes memory returnData) = ISafe(account).execTransactionFromModuleReturnData({
            to: account,
            value: 0,
            data: abi.encodeWithSignature("isModuleEnabled(address)", address(this)),
            operation: uint8(Enum.Operation.Call)
        });
        if (!success) {
            revert ModuleEnabledCheckFailed(account, address(this));
        }
        return abi.decode(returnData, (bool));
    }

    /**
     * @notice Executes recovery on a Safe account. Must be called by the trusted recovery manager
     * @param account The account to execute recovery for
     * @param recoveryCalldata The recovery calldata that should be executed on the Safe
     * being recovered
     */
    function recover(address account, bytes calldata recoveryCalldata) public {
        if (msg.sender != emailRecoveryManager) {
            revert NotTrustedRecoveryManager();
        }

        bytes4 calldataSelector = bytes4(recoveryCalldata[:4]);
        if (calldataSelector != selector) {
            revert InvalidSelector(calldataSelector);
        }

        bool success = ISafe(account).execTransactionFromModule({
            to: account,
            value: 0,
            data: recoveryCalldata,
            operation: uint8(Enum.Operation.Call)
        });
        if (!success) {
            revert RecoveryFailed(account);
        }

        emit RecoveryExecuted(account);
    }
}
