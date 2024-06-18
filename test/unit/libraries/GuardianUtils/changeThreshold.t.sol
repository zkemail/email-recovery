// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";

contract GuardianUtils_changeThreshold_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_SetupNotCalled() public {
        vm.expectRevert(GuardianUtils.SetupNotCalled.selector);
        emailRecoveryManager.changeThreshold(threshold);
    }

    function test_RevertWhen_ThresholdExceedsTotalWeight() public {
        uint256 highThreshold = totalWeight + 1;

        vm.startPrank(accountAddress);
        vm.expectRevert(GuardianUtils.ThresholdCannotExceedTotalWeight.selector);
        emailRecoveryManager.changeThreshold(highThreshold);
    }

    function test_RevertWhen_ThresholdIsZero() public {
        uint256 zeroThreshold = 0;

        vm.startPrank(accountAddress);
        vm.expectRevert(GuardianUtils.ThresholdCannotBeZero.selector);
        emailRecoveryManager.changeThreshold(zeroThreshold);
    }

    function test_ChangeThreshold_IncreaseThreshold() public {
        uint256 newThreshold = threshold + 1;

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit GuardianUtils.ChangedThreshold(accountAddress, newThreshold);
        emailRecoveryManager.changeThreshold(newThreshold);

        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length);
        assertEq(guardianConfig.threshold, newThreshold);
    }

    function test_ChangeThreshold_DecreaseThreshold() public {
        uint256 newThreshold = threshold - 1;

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit GuardianUtils.ChangedThreshold(accountAddress, newThreshold);
        emailRecoveryManager.changeThreshold(newThreshold);

        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length);
        assertEq(guardianConfig.threshold, newThreshold);
    }
}
