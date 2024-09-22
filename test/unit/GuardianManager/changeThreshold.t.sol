// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract GuardianManager_changeThreshold_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.changeThreshold(threshold);
    }

    function test_RevertWhen_SetupNotCalled() public {
        vm.expectRevert(IGuardianManager.SetupNotCalled.selector);
        emailRecoveryModule.changeThreshold(threshold);
    }

    function test_RevertWhen_ThresholdExceedsTotalWeight() public {
        uint256 highThreshold = totalWeight + 1;

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.ThresholdExceedsTotalWeight.selector, highThreshold, totalWeight
            )
        );
        emailRecoveryModule.changeThreshold(highThreshold);
    }

    function test_RevertWhen_ThresholdIsZero() public {
        uint256 zeroThreshold = 0;

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.ThresholdCannotBeZero.selector);
        emailRecoveryModule.changeThreshold(zeroThreshold);
    }

    function test_ChangeThreshold_IncreaseThreshold() public {
        uint256 newThreshold = threshold + 1;

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IGuardianManager.ChangedThreshold(accountAddress1, newThreshold);
        emailRecoveryModule.changeThreshold(newThreshold);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, guardians1.length);
        assertEq(guardianConfig.threshold, newThreshold);
    }

    function test_ChangeThreshold_DecreaseThreshold() public {
        uint256 newThreshold = threshold - 1;

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IGuardianManager.ChangedThreshold(accountAddress1, newThreshold);
        emailRecoveryModule.changeThreshold(newThreshold);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, guardians1.length);
        assertEq(guardianConfig.threshold, newThreshold);
    }
}
