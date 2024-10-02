// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_getRecoveryConfig_Test is UnitBase {
    uint256 public newDelay = 1 days;
    uint256 public newExpiry = 4 weeks;

    function setUp() public override {
        super.setUp();

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress1);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }

    function test_GetRecoveryConfig_Succeeds() public view {
        IEmailRecoveryManager.RecoveryConfig memory result =
            emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(result.delay, newDelay);
        assertEq(result.expiry, newExpiry);
    }
}
