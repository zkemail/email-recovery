// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract EmailRecoveryManager_updateRecoveryConfig_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_UpdateRecoveryConfig_RevertWhen_AlreadyRecovering() public {
        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(delay, expiry);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, recoveryDataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, recoveryDataHash, accountSalt2);

        vm.startPrank(accountAddress);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_AccountNotConfigured() public {
        address nonConfiguredAccount = address(0);
        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(delay, expiry);

        vm.startPrank(nonConfiguredAccount);
        vm.expectRevert(IEmailRecoveryManager.AccountNotConfigured.selector);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_DelayMoreThanExpiry() public {
        uint256 invalidDelay = expiry + 1 seconds;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(invalidDelay, expiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.DelayMoreThanExpiry.selector, invalidDelay, expiry
            )
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShort() public {
        uint256 newDelay = 1 days;
        uint256 newExpiry = 2 days;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryWindowTooShort.selector, newExpiry - newDelay
            )
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShortByOneSecond() public {
        uint256 newDelay = 1 seconds;
        uint256 newExpiry = 2 days;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryWindowTooShort.selector, newExpiry - newDelay
            )
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_SucceedsWhenRecoveryWindowEqualsMinimumRecoveryWindow()
        public
    {
        uint256 newDelay = 0 seconds;
        uint256 newExpiry = 2 days;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }

    function test_UpdateRecoveryConfig_Succeeds() public {
        uint256 newDelay = 1 days;
        uint256 newExpiry = 4 weeks;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigUpdated(
            accountAddress, recoveryConfig.delay, recoveryConfig.expiry
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }
}
