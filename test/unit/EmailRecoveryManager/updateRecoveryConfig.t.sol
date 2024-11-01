// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract EmailRecoveryManager_updateRecoveryConfig_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_UpdateRecoveryConfig_RevertWhen_KillSwitchEnabled() public {
        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(delay, expiry);

        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        vm.startPrank(accountAddress1);
        vm.expectRevert(IEmailRecoveryManager.KillSwitchEnabled.selector);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_AlreadyRecovering() public {
        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(delay, expiry);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        vm.startPrank(accountAddress1);
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

    function test_UpdateRecoveryConfig_RevertWhen_DelayLessThanMinimumDelay_OneSecondOff() public {
        uint256 invalidDelay = minimumDelay - 1 seconds;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(invalidDelay, expiry);

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.DelayLessThanMinimumDelay.selector,
                invalidDelay,
                emailRecoveryModule.minimumDelay()
            )
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_DelayLessThanMinimumDelay_ZeroSeconds() public {
        uint256 invalidDelay = 0 seconds;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(invalidDelay, expiry);

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.DelayLessThanMinimumDelay.selector,
                invalidDelay,
                emailRecoveryModule.minimumDelay()
            )
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_DelayMoreThanExpiry() public {
        uint256 invalidDelay = expiry + 1 seconds;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(invalidDelay, expiry);

        vm.startPrank(accountAddress1);
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

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryWindowTooShort.selector, newExpiry - newDelay
            )
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShortByOneSecond() public {
        uint256 newDelay = 1 days + 1 seconds;
        uint256 newExpiry = 3 days;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryWindowTooShort.selector, newExpiry - newDelay
            )
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_Success_WithMinimumDelayOfZero() public {
        uint256 newMinimumDelay = 0;
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        UniversalEmailRecoveryModule newEmailRecoveryModule = new UniversalEmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(4),
            newMinimumDelay,
            killSwitchAuthorizer,
            false
        );

        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(newEmailRecoveryModule),
            data: abi.encode(
                validatorAddress,
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });

        uint256 newDelay = 0 seconds;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, expiry);

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigUpdated(
            accountAddress1, newDelay, recoveryConfig.expiry
        );
        newEmailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = newEmailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, expiry);
    }

    function test_UpdateRecoveryConfig_Success_WhenDelayOneSecondOffMinimum() public {
        uint256 newDelay = minimumDelay + 1 seconds;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, expiry);

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigUpdated(
            accountAddress1, newDelay, recoveryConfig.expiry
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, expiry);
    }

    function test_UpdateRecoveryConfig_Success_WhenDelayEqualToMinimum() public {
        uint256 newDelay = emailRecoveryModule.minimumDelay();

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, expiry);

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigUpdated(
            accountAddress1, newDelay, recoveryConfig.expiry
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, expiry);
    }

    function test_UpdateRecoveryConfig_Success_WhenLongDelayAndExpiry() public {
        uint256 newDelay = 52 weeks;
        uint256 newExpiry = 104 weeks;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigUpdated(accountAddress1, newDelay, newExpiry);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }

    function test_UpdateRecoveryConfig_SucceedsWhenRecoveryWindowEqualsMinimumRecoveryWindow()
        public
    {
        uint256 newDelay = 18 hours;
        uint256 newExpiry = 2 days + 18 hours;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigUpdated(accountAddress1, newDelay, newExpiry);
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }

    function test_UpdateRecoveryConfig_Succeeds() public {
        uint256 newDelay = 1 days;
        uint256 newExpiry = 4 weeks;

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            IEmailRecoveryManager.RecoveryConfig(newDelay, newExpiry);

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigUpdated(
            accountAddress1, recoveryConfig.delay, recoveryConfig.expiry
        );
        emailRecoveryModule.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }
}
