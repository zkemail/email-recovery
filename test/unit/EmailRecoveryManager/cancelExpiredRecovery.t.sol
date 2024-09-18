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

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, bytes32(0));

        vm.startPrank(otherAddress);
        vm.expectRevert(IEmailRecoveryManager.NoRecoveryInProcess.selector);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);
    }

    function test_CancelExpiredRecovery_RevertWhen_PartialRequest_ExpiryNotPassed() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

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
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

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
        handleRecovery(recoveryDataHash, accountSalt1);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.warp(block.timestamp + expiry);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress1);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");
    }

    function test_CancelExpiredRecovery_FullRequest_SucceedsWhenExecuteBeforeEqualsTimestamp()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        // executeBefore == block.timestamp
        vm.warp(block.timestamp + expiry);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress1);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");
    }

    function test_CancelExpiredRecovery_FullRequest_SucceedsWhenExecuteBeforeIsLessThanTimestamp()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        // executeBefore < block.timestamp
        vm.warp(block.timestamp + expiry + 1 seconds);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress1);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");
    }
}
