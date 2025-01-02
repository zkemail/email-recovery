// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import { EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

import { CommandHandlerType } from "../../Base.t.sol";
import { OwnableValidatorRecovery_UniversalEmailRecoveryModule_Base } from
    "../OwnableValidatorRecovery/UniversalEmailRecoveryModule/UniversalEmailRecoveryModuleBase.t.sol";

contract EmailRecoveryManager_Integration_Test is
    OwnableValidatorRecovery_UniversalEmailRecoveryModule_Base
{
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_HandleAcceptanceCalled_BeforeConfigureRecovery() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress
        );

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeTimeStampChanged() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert("invalid timestamp");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleAcceptanceCalled_DuringRecovery() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert();
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeHandleAcceptance() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_RevertWhen_HandleRecoveryCalled_DuringRecoveryWithoutGuardianBeingDeployed()
        public
    {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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

        (,, uint256 currentWeight,) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(currentWeight, 0);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[2], recoveryDataHash1, emailRecoveryModuleAddress
        );

        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        (,, currentWeight,) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(currentWeight, 1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeConfigureRecovery() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.expectRevert(IEmailRecoveryManager.NoRecoveryConfigured.selector);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeHandleAcceptance() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        vm.expectRevert(
            abi.encodeWithSelector(IEmailRecoveryManager.NotEnoughApprovals.selector, 0, threshold)
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeProcessRecovery() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);

        vm.expectRevert(
            abi.encodeWithSelector(IEmailRecoveryManager.NotEnoughApprovals.selector, 0, threshold)
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_TryRecoverFunctionsWhenModuleNotInstalled() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.expectRevert(IEmailRecoveryManager.NoRecoveryConfigured.selector);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_StaleRecoveryRequest() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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

        (
            uint256 _executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        bool hasGuardian3Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(_executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(recoveryDataHash, bytes32(0));
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(hasGuardian3Voted, false);
    }

    function test_CancelExpiredRecoveryRequest() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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

        (
            uint256 _executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        bool hasGuardian3Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(_executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(recoveryDataHash, bytes32(0));
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(hasGuardian3Voted, false);
    }

    function test_CannotComplete_CancelledExpiredRecoveryRequest() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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

        (
            uint256 _executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        bool hasGuardian3Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(_executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(recoveryDataHash, bytes32(0));
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(hasGuardian3Voted, false);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.NotEnoughApprovals.selector, currentWeight, threshold
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);
    }

    function test_Ownable_renounceOwnership() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();
        assertTrue(emailRecoveryModule.killSwitchEnabled());

        // renounce ownership
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.renounceOwnership();
        vm.stopPrank();

        address owner = emailRecoveryModule.owner();
        assertEq(owner, address(0));

        vm.prank(killSwitchAuthorizer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, killSwitchAuthorizer
            )
        );
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();
    }

    function test_Ownable_transferOwnership() public {
        address newOwner = vm.addr(99);

        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();
        assertTrue(emailRecoveryModule.killSwitchEnabled());

        // transfer ownership
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.transferOwnership(newOwner);
        vm.stopPrank();

        address owner = emailRecoveryModule.owner();
        assertEq(owner, newOwner);

        vm.prank(newOwner);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();
        assertFalse(emailRecoveryModule.killSwitchEnabled());

        vm.prank(killSwitchAuthorizer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector, killSwitchAuthorizer
            )
        );
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();
        assertFalse(emailRecoveryModule.killSwitchEnabled());
    }
}
