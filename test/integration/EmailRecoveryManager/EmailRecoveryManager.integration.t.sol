// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorRecoveryBase } from
    "../OwnableValidatorRecovery/OwnableValidatorRecoveryBase.t.sol";

contract EmailRecoveryManager_Integration_Test is OwnableValidatorRecoveryBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_HandleAcceptanceCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(accountSalt1);

        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeTimeStampChanged() public {
        acceptGuardian(accountSalt1);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt1);

        vm.expectRevert("invalid timestamp");
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleAcceptanceCalled_DuringRecovery() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(accountSalt1);

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(accountSalt2);

        vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleAcceptanceCalled_AfterRecoveryProcessedButBeforeCompleteRecovery(
    )
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(accountSalt1);
        handleRecovery(accountSalt2);

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(accountSalt3);

        vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_HandleNewAcceptanceSucceeds_AfterCompleteRecovery() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(accountSalt1);
        handleRecovery(accountSalt2);
        vm.warp(block.timestamp + delay);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

        acceptGuardian(accountSalt3);

        GuardianStorage memory guardianStorage =
            emailRecoveryManager.getGuardian(accountAddress, guardian3);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt1);

        vm.expectRevert();
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeHandleAcceptance() public {
        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt1);

        vm.expectRevert("guardian is not deployed");
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_DuringRecoveryWithoutGuardianBeingDeployed()
        public
    {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(accountSalt1);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt2);

        vm.expectRevert("guardian is not deployed");
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterRecoveryProcessedButBeforeCompleteRecovery()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(accountSalt1);
        handleRecovery(accountSalt2);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt3);

        vm.expectRevert("guardian is not deployed");
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterCompleteRecovery() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(accountSalt1);
        handleRecovery(accountSalt2);
        vm.warp(block.timestamp + delay);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt1);

        vm.expectRevert("email nullifier already used");
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.NoRecoveryConfigured.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeHandleAcceptance() public {
        vm.expectRevert(IEmailRecoveryManager.NotEnoughApprovals.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeProcessRecovery() public {
        acceptGuardian(accountSalt1);

        vm.expectRevert(IEmailRecoveryManager.NotEnoughApprovals.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_TryConfigureAndAcceptanceFunctionsWhenModuleNotInstalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.configureRecovery(guardians, guardianWeights, threshold, delay, expiry);
        vm.stopPrank();

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(accountSalt1);
        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);

        emailAuthMsg = getAcceptanceEmailAuthMessage(accountSalt2);
        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_TryRecoverFunctionsWhenModuleNotInstalled() public {
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(accountSalt1);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);

        emailAuthMsg = getAcceptanceEmailAuthMessage(accountSalt2);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.warp(12 seconds);

        emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt1);
        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);

        emailAuthMsg = getRecoveryEmailAuthMessage(accountSalt2);
        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_TryCompleteRecoveryWhenModuleNotInstalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.NoRecoveryConfigured.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_StaleRecoveryRequest() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(accountSalt1);
        handleRecovery(accountSalt2);

        vm.warp(10 weeks);

        vm.expectRevert(IEmailRecoveryManager.RecoveryRequestExpired.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

        // Can cancel recovery even when stale
        vm.startPrank(accountAddress);
        emailRecoveryManager.cancelRecovery();
        vm.stopPrank();

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryManager.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
    }
}
