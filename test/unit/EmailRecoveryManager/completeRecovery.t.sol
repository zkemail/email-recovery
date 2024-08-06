// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_completeRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_CompleteRecovery_RevertWhen_InvalidAccountAddress() public {
        address invalidAccount = address(0);

        vm.expectRevert(IEmailRecoveryManager.InvalidAccountAddress.selector);
        emailRecoveryModule.completeRecovery(invalidAccount, recoveryCalldata);
    }

    function test_CompleteRecovery_RevertWhen_NotEnoughApprovals() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        // only one guardian added and one approval

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.NotEnoughApprovals.selector, guardianWeights[0], threshold
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_CompleteRecovery_RevertWhen_DelayNotPassed() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        // one second before it should be valid
        vm.warp(block.timestamp + delay - 1 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.DelayNotPassed.selector,
                block.timestamp,
                block.timestamp + delay
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampEqualToExpiry()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);
        uint256 executeAfter = block.timestamp + expiry;

        // block.timestamp == recoveryRequest.executeBefore
        vm.warp(block.timestamp + expiry);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampMoreThanExpiry()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);
        uint256 executeAfter = block.timestamp + expiry;

        // block.timestamp > recoveryRequest.executeBefore
        vm.warp(block.timestamp + expiry + 1 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.RecoveryRequestExpired.selector, block.timestamp, executeAfter
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_CompleteRecovery_RevertWhen_InvalidCalldataHash() public {
        bytes memory invalidRecoveryCalldata = bytes("Invalid calldata");

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        vm.warp(block.timestamp + delay);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidCalldataHash.selector,
                keccak256(invalidRecoveryCalldata),
                calldataHash
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress, invalidRecoveryCalldata);
    }

    function test_CompleteRecovery_Succeeds() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        vm.warp(block.timestamp + delay);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCompleted(accountAddress);
        emailRecoveryModule.completeRecovery(accountAddress, recoveryCalldata);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.calldataHash, "");

        bool isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertTrue(isActivated);
    }

    function test_CompleteRecovery_SucceedsAlmostExpiry() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        vm.warp(block.timestamp + expiry - 1 seconds);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCompleted(accountAddress);
        emailRecoveryModule.completeRecovery(accountAddress, recoveryCalldata);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.calldataHash, "");

        bool isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertTrue(isActivated);
    }
}
