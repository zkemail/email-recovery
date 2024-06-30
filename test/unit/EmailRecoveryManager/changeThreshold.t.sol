// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";

contract EmailRecoveryManager_changeThreshold_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        emailRecoveryManager.changeThreshold(threshold);
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
