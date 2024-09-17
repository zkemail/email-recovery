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
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        // only one guardian added and one approval

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.NotEnoughApprovals.selector, guardianWeights[0], threshold
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_DelayNotPassed() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        // one second before it should be valid
        vm.warp(block.timestamp + delay - 1 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.DelayNotPassed.selector,
                block.timestamp,
                block.timestamp + delay
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampEqualToExpiry()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);
        uint256 executeAfter = block.timestamp + expiry;

        // block.timestamp == recoveryRequest.executeBefore
        vm.warp(block.timestamp + expiry);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampMoreThanExpiry()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);
        uint256 executeAfter = block.timestamp + expiry;

        // block.timestamp > recoveryRequest.executeBefore
        vm.warp(block.timestamp + expiry + 1 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryData);
    }

    function test_CompleteRecovery_RevertWhen_InvalidRecoveryDataHash() public {
        bytes memory invalidRecoveryData = bytes("Invalid calldata");

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        vm.warp(block.timestamp + delay);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidRecoveryDataHash.selector,
                keccak256(invalidRecoveryData),
                recoveryDataHash
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, invalidRecoveryData);
    }

    function test_CompleteRecovery_Succeeds() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        vm.warp(block.timestamp + delay);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCompleted(accountAddress);
        emailRecoveryModule.completeRecovery(accountAddress, recoveryData);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");
    }

    function test_CompleteRecovery_SucceedsAlmostExpiry() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        vm.warp(block.timestamp + expiry - 1 seconds);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCompleted(accountAddress);
        emailRecoveryModule.completeRecovery(accountAddress, recoveryData);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");
    }
}
