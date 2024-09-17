// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_getRecoveryConfig_Test is UnitBase {
    uint256 newDelay = 1 days;
    uint256 newExpiry = 4 weeks;

    function setUp() public override {
        super.setUp();

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }

    function test_GetRecoveryConfig_Succeeds() public view {
        IEmailRecoveryManager.RecoveryConfig memory result =
            emailRecoveryModule.getRecoveryConfig(accountAddress);
        assertEq(result.delay, newDelay);
        assertEq(result.expiry, newExpiry);
    }
}
