// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ISafe } from "../interfaces/ISafe.sol";
import { Enum } from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import { EmailRecoveryManager } from "../EmailRecoveryManager.sol";

/**
 * @title SafeEmailRecoveryModule
 * @notice A Safe module that recovers a Safe owner via ZK Email. This contract provides a simple
 * mechanism for recovering Safe smart accounts. It facilitates recovery by integration with the
 * email recovery manager contract. The module defines how a recovery request is executed on a
 * Safe, while the recovery manager defines what a valid recovery request is.
 */
contract SafeEmailRecoveryModule is EmailRecoveryManager {
    /*
     * The function selector for rotating an owner on a Safe
     */
    bytes4 public constant selector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

    event RecoveryExecuted(address indexed account);

    error InvalidAccount(address account);
    error InvalidSelector(bytes4 selector);
    error RecoveryFailed(address account);
    error ResetFailed(address account);

    constructor(
        address verifier,
        address dkimRegistry,
        address emailAuthImpl,
        address subjectHandler
    )
        EmailRecoveryManager(verifier, dkimRegistry, emailAuthImpl, subjectHandler)
    { }

    /**
     * Check if a recovery request can be initiated based on guardian acceptance
     * @param account The smart account to check
     * @return true if the recovery request can be started, false otherwise
     */
    function canStartRecoveryRequest(address account) external view returns (bool) {
        GuardianConfig memory guardianConfig = getGuardianConfig(account);

        return guardianConfig.acceptedWeight >= guardianConfig.threshold;
    }

    /**
     * @notice Executes recovery on a Safe account. Called from the recovery manager once a recovery
     * attempt has been processed
     * @param account The account to execute recovery for
     * @param recoveryData The recovery data that should be executed on the Safe
     * being recovered. recoveryData = abi.encode(safeAccount, recoveryFunctionCalldata)
     */
    function recover(address account, bytes calldata recoveryData) internal override {
        (address encodedAccount, bytes memory recoveryCalldata) =
            abi.decode(recoveryData, (address, bytes));

        if (encodedAccount == address(0) || encodedAccount != account) {
            revert InvalidAccount(encodedAccount);
        }

        bytes4 calldataSelector;
        assembly {
            calldataSelector := mload(add(recoveryCalldata, 32))
        }
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

    /**
     * @notice Resets the guardian states for the account when the module is disabled
     * @param account The account to reset the states for
     */
    function resetWhenDisabled(address account) external {
        if (account == address(0) ) {
            revert InvalidAccount(account);
        }
        if (ISafe(account).isModuleEnabled(address(this)) == true) {
            revert ResetFailed(account);
        }
        deInitRecoveryModule(account);
    }
}
