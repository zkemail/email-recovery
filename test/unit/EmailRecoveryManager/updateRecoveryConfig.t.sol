// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_updateRecoveryConfig_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_UpdateRecoveryConfig_RevertWhen_AlreadyRecovering() public {
    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(delay, expiry);

    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);
    // }

    // function test_UpdateRecoveryConfig_RevertWhen_AccountNotConfigured() public {
    //     address nonConfiguredAccount = address(0);
    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(delay, expiry);

    //     vm.startPrank(nonConfiguredAccount);
    //     vm.expectRevert(IEmailRecoveryManager.AccountNotConfigured.selector);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);
    // }

    // function test_UpdateRecoveryConfig_RevertWhen_InvalidRecoveryModule() public {
    //     address invalidRecoveryModule = address(0);

    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(delay, expiry);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(IEmailRecoveryManager.InvalidRecoveryModule.selector);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);
    // }

    // function test_UpdateRecoveryConfig_RevertWhen_DelayMoreThanExpiry() public {
    //     uint256 invalidDelay = expiry + 1 seconds;

    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(invalidDelay, expiry);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(IEmailRecoveryManager.DelayMoreThanExpiry.selector);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);
    // }

    // function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShort() public {
    //     uint256 newDelay = 1 days;
    //     uint256 newExpiry = 2 days;

    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(IEmailRecoveryManager.RecoveryWindowTooShort.selector);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);
    // }

    // function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShortByOneSecond() public {
    //     uint256 newDelay = 1 seconds;
    //     uint256 newExpiry = 2 days;

    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(IEmailRecoveryManager.RecoveryWindowTooShort.selector);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);
    // }

    // function test_UpdateRecoveryConfig_SucceedsWhenRecoveryWindowEqualsMinimumRecoveryWindow()
    //     public
    // {
    //     uint256 newDelay = 0 seconds;
    //     uint256 newExpiry = 2 days;

    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

    //     vm.startPrank(accountAddress);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);

    //     recoveryConfig = emailRecoveryManager.getRecoveryConfig(accountAddress);
    //     assertEq(recoveryConfig.delay, newDelay);
    //     assertEq(recoveryConfig.expiry, newExpiry);
    // }

    // function test_UpdateRecoveryConfig_Succeeds() public {
    //     address newRecoveryModule = recoveryModuleAddress;
    //     uint256 newDelay = 1 days;
    //     uint256 newExpiry = 4 weeks;

    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

    //     vm.startPrank(accountAddress);
    //     emailRecoveryManager.updateRecoveryConfig(recoveryConfig);

    //     recoveryConfig = emailRecoveryManager.getRecoveryConfig(accountAddress);
    //     assertEq(recoveryConfig.delay, newDelay);
    //     assertEq(recoveryConfig.expiry, newExpiry);
    // }
}
