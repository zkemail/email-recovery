// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorRecovery_UniversalEmailRecoveryModule_Base } from
    "../OwnableValidatorRecovery/UniversalEmailRecoveryModule/UniversalEmailRecoveryModuleBase.t.sol";

contract EmailRecoveryManager_Integration_Test is
    OwnableValidatorRecovery_UniversalEmailRecoveryModule_Base
{
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_HandleAcceptanceCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(accountAddress1, guardians1[0]);

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeTimeStampChanged() public {
        acceptGuardian(accountAddress1, guardians1[0]);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[0], recoveryDataHash1);

        vm.expectRevert("invalid timestamp");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleAcceptanceCalled_DuringRecovery() public {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);

        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(accountAddress1, guardians1[1]);

        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleAcceptanceCalled_AfterRecoveryProcessedButBeforeCompleteRecovery(
    )
        public
    {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);

        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(accountAddress1, guardians1[2]);

        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_HandleNewAcceptanceSucceeds_AfterCompleteRecovery() public {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        acceptGuardian(accountAddress1, guardians1[2]);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[2]);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[0], recoveryDataHash1);

        vm.expectRevert();
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeHandleAcceptance() public {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[0], recoveryDataHash1);

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_DuringRecoveryWithoutGuardianBeingDeployed()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[2], recoveryDataHash1);

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterRecoveryProcessedButBeforeCompleteRecovery()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[2], recoveryDataHash1);

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_HandleRecoveryCalled_AfterCompleteRecoveryStartsNewRecoveryRequest() public {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        acceptGuardian(accountAddress1, guardians1[2]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.currentWeight, 0);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[2], recoveryDataHash1);

        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.currentWeight, 1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.NoRecoveryConfigured.selector);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeHandleAcceptance() public {
        vm.expectRevert(
            abi.encodeWithSelector(IEmailRecoveryManager.NotEnoughApprovals.selector, 0, threshold)
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeProcessRecovery() public {
        acceptGuardian(accountAddress1, guardians1[0]);

        vm.expectRevert(
            abi.encodeWithSelector(IEmailRecoveryManager.NotEnoughApprovals.selector, 0, threshold)
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_TryRecoverFunctionsWhenModuleNotInstalled() public {
        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(accountAddress1, guardians1[0]);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);

        emailAuthMsg = getAcceptanceEmailAuthMessage(accountAddress1, guardians1[1]);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);

        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.warp(12 seconds);

        emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[0], recoveryDataHash1);
        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);

        emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[1], recoveryDataHash1);
        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_TryCompleteRecoveryWhenModuleNotInstalled() public {
        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.NoRecoveryConfigured.selector);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_StaleRecoveryRequest() public {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);
        uint256 executeAfter = block.timestamp + expiry;

        vm.warp(10 weeks);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        // Can cancel recovery even when stale
        vm.startPrank(accountAddress1);
        emailRecoveryModule.cancelRecovery();
        vm.stopPrank();

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
    }

    function test_CancelExpiredRecoveryRequest() public {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);
        uint256 executeAfter = block.timestamp + expiry;

        vm.warp(executeAfter);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        // Can cancel recovery even when stale
        vm.startPrank(vm.addr(1));
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
        vm.stopPrank();

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
    }
}
