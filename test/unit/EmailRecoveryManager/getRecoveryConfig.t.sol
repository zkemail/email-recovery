// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {IEmailRecoveryManager} from "src/interfaces/IEmailRecoveryManager.sol";
import {EmailRecoveryModule} from "src/modules/EmailRecoveryModule.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract EmailRecoveryManager_getRecoveryConfig_Test is UnitBase {
    uint256 newDelay = 1 days;
    uint256 newExpiry = 4 weeks;

    function setUp() public override {
        super.setUp();

        IEmailRecoveryManager.RecoveryConfig
            memory recoveryConfig = IEmailRecoveryManager.RecoveryConfig(
                newDelay,
                newExpiry
            );

        vm.startPrank(accountAddress);
        emailRecoveryManager.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryManager.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }

    function test_GetRecoveryConfig_Succeeds() public {
        IEmailRecoveryManager.RecoveryConfig
            memory result = emailRecoveryManager.getRecoveryConfig(
                accountAddress
            );
        assertEq(result.delay, newDelay);
        assertEq(result.expiry, newExpiry);
    }
}
