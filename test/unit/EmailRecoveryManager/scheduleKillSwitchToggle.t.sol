// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_scheduleKillSwitchToggle_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ScheduleKillSwitchToggle_RevertWhen_NotOwner() public {
        vm.prank(zkEmailDeployer);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, zkEmailDeployer)
        );
        emailRecoveryModule.scheduleKillSwitchToggle();
    }

    function test_ScheduleKillSwitchToggle_Succeeds() public {
        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertFalse(killSwitchEnabled);

        vm.prank(killSwitchAuthorizer);
        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchScheduled(true, uint48(block.timestamp + 7 days));
        emailRecoveryModule.scheduleKillSwitchToggle();
    }

    function test_ScheduleKillSwitchToggle_Succeeds_MultipleSchedules() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();

        // Schedule again before executing
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();

        // Warp to after the delay period
        vm.warp(block.timestamp + 7 days);

        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchToggled(true);
        emailRecoveryModule.executeKillSwitchToggle();

        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertTrue(killSwitchEnabled);
    }
}
