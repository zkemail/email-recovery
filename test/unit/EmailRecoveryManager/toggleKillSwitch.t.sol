// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_toggleKillSwitch_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ToggleKillSwitch_RevertWhen_NotOwner() public {
        vm.prank(zkEmailDeployer);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, zkEmailDeployer)
        );
        emailRecoveryModule.toggleKillSwitch();
    }

    function test_ToggleKillSwitch_Succeeds() public {
        bool killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertFalse(killSwitchEnabled);

        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertTrue(killSwitchEnabled);

        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        killSwitchEnabled = emailRecoveryModule.killSwitchEnabled();
        assertFalse(killSwitchEnabled);
    }
}
