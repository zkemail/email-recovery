// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_cancelExpiredRecovery_Test is UnitBase {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_CancelExpiredRecovery_RevertWhen_KillSwitchEnabled() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.KillSwitchEnabled.selector);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
    }

    function test_CancelExpiredRecovery_RevertWhen_NoRecoveryInProcess() public {
        vm.startPrank(accountAddress1);
        vm.expectRevert(IEmailRecoveryManager.NoRecoveryInProcess.selector);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
    }

    function test_CancelExpiredRecovery_CannotCancelNotStartedRecoveryRequest() public {
        address otherAddress = address(99);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, bytes32(0));
        assertEq(previousRecoveryRequest.previousGuardianInitiated, address(0));
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);

        vm.startPrank(otherAddress);
        vm.expectRevert(IEmailRecoveryManager.NoRecoveryInProcess.selector);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
    }

    function test_CancelExpiredRecovery_RevertWhen_PartialRequest_ExpiryNotPassed() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 1);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, false);

        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryHasNotExpired.selector,
                accountAddress1,
                block.timestamp,
                block.timestamp + expiry
            )
        );
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
    }

    function test_CancelExpiredRecovery_RevertWhen_FullRequest_ExpiryNotPassed() public {
        address otherAddress = address(99);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, block.timestamp + delay);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 3);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);

        // executeBefore > block.timestamp
        vm.startPrank(otherAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryHasNotExpired.selector,
                accountAddress1,
                block.timestamp,
                block.timestamp + expiry
            )
        );
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
    }

    function test_CancelExpiredRecovery_PartialRequest_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 1);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, false);

        vm.warp(block.timestamp + expiry);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress1);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        (executeAfter, executeBefore, currentWeight, recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        previousRecoveryRequest = emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(recoveryDataHash, "");
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(
            previousRecoveryRequest.cancelRecoveryCooldown,
            block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN()
        );
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
    }

    function test_CancelExpiredRecovery_FullRequest_SucceedsWhenExecuteBeforeEqualsTimestamp()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, block.timestamp + delay);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 3);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);

        // executeBefore == block.timestamp
        vm.warp(block.timestamp + expiry);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress1);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        (executeAfter, executeBefore, currentWeight, _recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        previousRecoveryRequest = emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, "");
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(
            previousRecoveryRequest.cancelRecoveryCooldown,
            block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN()
        );
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
    }

    function test_CancelExpiredRecovery_FullRequest_SucceedsWhenExecuteBeforeIsLessThanTimestamp()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, block.timestamp + delay);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 3);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);

        // executeBefore < block.timestamp
        vm.warp(block.timestamp + expiry + 1 seconds);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress1);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        (executeAfter, executeBefore, currentWeight, _recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        previousRecoveryRequest = emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, "");
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(
            previousRecoveryRequest.cancelRecoveryCooldown,
            block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN()
        );
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
    }
}
