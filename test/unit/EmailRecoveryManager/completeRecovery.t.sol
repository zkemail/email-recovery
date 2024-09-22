// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_completeRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_CompleteRecovery_RevertWhen_InvalidAccountAddress() public {
        address invalidAccount = address(0);

        vm.expectRevert(IEmailRecoveryManager.InvalidAccountAddress.selector);
        emailRecoveryModule.completeRecovery(invalidAccount, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_NotEnoughApprovals() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        // only one guardian added and one approval

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.NotEnoughApprovals.selector, guardianWeights[0], threshold
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_DelayNotPassed() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        // one second before it should be valid
        vm.warp(block.timestamp + delay - 1 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.DelayNotPassed.selector,
                block.timestamp,
                block.timestamp + delay
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampEqualToExpiry()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);
        uint256 executeAfter = block.timestamp + expiry;

        // block.timestamp == recoveryRequest.executeBefore
        vm.warp(block.timestamp + expiry);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampMoreThanExpiry()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);
        uint256 executeAfter = block.timestamp + expiry;

        // block.timestamp > recoveryRequest.executeBefore
        vm.warp(block.timestamp + expiry + 1 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_InvalidRecoveryDataHash() public {
        bytes memory invalidRecoveryData = bytes("Invalid calldata");

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        vm.warp(block.timestamp + delay);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.NotEnoughApprovals.selector,
                0,
                3
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, invalidRecoveryData);
    }

    function test_CompleteRecovery_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        vm.warp(block.timestamp + delay);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCompleted(accountAddress1);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);

        // IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
        //     emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, 0);
        // assertEq(recoveryRequest.executeBefore, 0);
        // assertEq(recoveryRequest.currentWeight, 0);
        // assertEq(recoveryRequest.recoveryDataHash, "");
    }

    function test_CompleteRecovery_SucceedsAlmostExpiry() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        vm.warp(block.timestamp + expiry - 1 seconds);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCompleted(accountAddress1);
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);

        // IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
        //     emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, 0);
        // assertEq(recoveryRequest.executeBefore, 0);
        // assertEq(recoveryRequest.currentWeight, 0);
        // assertEq(recoveryRequest.recoveryDataHash, "");
    }
}
