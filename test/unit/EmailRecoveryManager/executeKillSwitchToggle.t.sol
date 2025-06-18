// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_executeKillSwitchToggle_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ExecuteKillSwitchToggle_RevertWhen_DelayNotElapsed() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();

        // Try to execute before delay has passed
        vm.expectRevert(IEmailRecoveryManager.KillSwitchDelayNotElapsed.selector);
        emailRecoveryModule.executeKillSwitchToggle();
    }

    function test_ExecuteKillSwitchToggle_Succeeds_AfterDelay() public {
        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertFalse(killSwitchEnabled);

        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();

        // Warp to after the delay period
        vm.warp(block.timestamp + 7 days);

        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchToggled(true);
        emailRecoveryModule.executeKillSwitchToggle();

        killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertTrue(killSwitchEnabled);
    }

    function test_ExecuteKillSwitchToggle_Succeeds_CanBeCalledByAnyone() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();

        // Warp to after the delay period
        vm.warp(block.timestamp + 7 days);

        // Execute from a different address
        vm.prank(vm.addr(10));
        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchToggled(true);
        emailRecoveryModule.executeKillSwitchToggle();

        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertTrue(killSwitchEnabled);
    }

    function test_ExecuteKillSwitchToggle_Succeeds_ToggleBackAndForth() public {
        // First toggle: false -> true
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();
        vm.warp(block.timestamp + 7 days);
        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchToggled(true);
        emailRecoveryModule.executeKillSwitchToggle();

        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertTrue(killSwitchEnabled);

        // Second toggle: true -> false
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();
        vm.warp(block.timestamp + 7 days);
        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchToggled(false);
        emailRecoveryModule.executeKillSwitchToggle();

        killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertFalse(killSwitchEnabled);
    }

    function test_ExecuteKillSwitchToggle_Succeeds_ExactDelayTime() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();

        // Warp to exactly the delay period
        vm.warp(block.timestamp + 7 days);

        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchToggled(true);
        emailRecoveryModule.executeKillSwitchToggle();

        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertTrue(killSwitchEnabled);
    }

    function test_ExecuteKillSwitchToggle_Succeeds_WellAfterDelay() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();

        // Warp to well after the delay period
        vm.warp(block.timestamp + 30 days);

        vm.expectEmit();
        emit IEmailRecoveryManager.KillSwitchToggled(true);
        emailRecoveryModule.executeKillSwitchToggle();

        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertTrue(killSwitchEnabled);
    }
}
