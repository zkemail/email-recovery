// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ISafe } from "../interfaces/ISafe.sol";
import { Enum } from "@safe-global/safe-contracts/contracts/common/Enum.sol";
import { EmailRecoveryManager } from "../EmailRecoveryManager.sol";

/**
 * A safe module that recovers a safe owner via ZK Email
 */
contract SafeEmailRecoveryModule is EmailRecoveryManager {
    bytes4 public constant selector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

    event RecoveryExecuted(address indexed account);

    error InvalidAccount(address account);
    error InvalidSelector(bytes4 selector);
    error RecoveryFailed(address account);

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
     * @notice Executes recovery on a Safe account. Called from the recovery manager
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
}
