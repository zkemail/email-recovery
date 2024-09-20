// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

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
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress
        );

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeTimeStampChanged() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert("invalid timestamp");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleAcceptanceCalled_DuringRecovery() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[1], emailRecoveryModuleAddress
        );

        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleAcceptanceCalled_AfterRecoveryProcessedButBeforeCompleteRecovery(
    )
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[2], emailRecoveryModuleAddress
        );

        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_HandleNewAcceptanceSucceeds_AfterCompleteRecovery() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[2]);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeConfigureRecovery() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert();
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeHandleAcceptance() public {
        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_DuringRecoveryWithoutGuardianBeingDeployed()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[2], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterRecoveryProcessedButBeforeCompleteRecovery()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[2], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_HandleRecoveryCalled_AfterCompleteRecoveryStartsNewRecoveryRequest() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        uint256 weight = emailRecoveryModule.getRecoveryDataHashWeight(accountAddress1, recoveryDataHash1);
        assertEq(weight, 0);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[2], recoveryDataHash1, emailRecoveryModuleAddress
        );

        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        weight = emailRecoveryModule.getRecoveryDataHashWeight(accountAddress1, recoveryDataHash1);
        assertEq(weight, 1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeConfigureRecovery() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

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
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);

        vm.expectRevert(
            abi.encodeWithSelector(IEmailRecoveryManager.NotEnoughApprovals.selector, 0, threshold)
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_TryRecoverFunctionsWhenModuleNotInstalled() public {
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);

        emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[1], emailRecoveryModuleAddress
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.warp(12 seconds);

        emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);

        emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_TryCompleteRecoveryWhenModuleNotInstalled() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.expectRevert(IEmailRecoveryManager.NoRecoveryConfigured.selector);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_StaleRecoveryRequest() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
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

        (uint256 _executeAfter, uint256 executeBefore) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        uint256 weight = emailRecoveryModule.getRecoveryDataHashWeight(accountAddress1, recoveryDataHash1);
        bool hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        bool hasGuardian3Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(_executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(weight, 0);
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(hasGuardian3Voted, false);
    }

    function test_CancelExpiredRecoveryRequest() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
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

        (uint256 _executeAfter, uint256 executeBefore) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        uint256 weight = emailRecoveryModule.getRecoveryDataHashWeight(accountAddress1, recoveryDataHash1);
        bool hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        bool hasGuardian3Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(_executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(weight, 0);
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(hasGuardian3Voted, false);
    }

    function test_CannotComplete_CancelledExpiredRecoveryRequest() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
        uint256 executeAfter = block.timestamp + expiry;

        vm.warp(executeAfter);
        // Can cancel recovery even when stale
        vm.startPrank(vm.addr(1));
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
        vm.stopPrank();

        (uint256 _executeAfter, uint256 executeBefore) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        uint256 weight = emailRecoveryModule.getRecoveryDataHashWeight(accountAddress1, recoveryDataHash1);
        bool hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        bool hasGuardian3Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(_executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(weight, 0);
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(hasGuardian3Voted, false);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.NotEnoughApprovals.selector,
                weight,
                threshold
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }
}
