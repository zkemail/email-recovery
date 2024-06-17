// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

// completeRecovery(accountAddress, recoveryCalldata)
contract ZkEmailRecovery_completeRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_CompleteRecovery_RevertWhen_NotCalledFromCorrectRouter() public {
    //     bytes memory recoveryCalldata = abi.encodeWithSignature(
    //         "changeOwner(address,address,address)", accountAddress, recoveryModuleAddress,
    // newOwner
    //     );
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.warp(block.timestamp + delay);

    //     vm.expectRevert(IEmailRecoveryManager.InvalidAccountAddress.selector);
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    // }

    // function test_CompleteRecovery_Succeeds() public {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.warp(block.timestamp + delay);

    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    // }
}

// completeRecovery(address account)
contract ZkEmailRecovery_completeRecoveryWithAddress_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_CompleteRecovery_RevertWhen_InvalidAccountAddress() public {
    //     bytes memory recoveryCalldata = abi.encodeWithSignature(
    //         "changeOwner(address,address,address)", accountAddress, recoveryModuleAddress,
    // newOwner
    //     address invalidAccount = address(0);

    //     vm.expectRevert(IEmailRecoveryManager.InvalidAccountAddress.selector);
    //     emailRecoveryManager.completeRecovery(invalidAccount, recoveryCalldata);
    // }

    // function test_CompleteRecovery_RevertWhen_NotEnoughApprovals() public {
    //     acceptGuardian(accountSalt1);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1); // only one guardian added and one
    //         // approval

    //     vm.expectRevert(IEmailRecoveryManager.NotEnoughApprovals.selector);
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    // }

    // function test_CompleteRecovery_RevertWhen_DelayNotPassed() public {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.warp(block.timestamp + delay - 1 seconds); // one second before it should be valid

    //     vm.expectRevert(IEmailRecoveryManager.DelayNotPassed.selector);
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    // }

    // function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampEqualToExpiry()
    //     public
    // {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.warp(block.timestamp + expiry); // block.timestamp == recoveryRequest.executeBefore

    //     vm.expectRevert(IEmailRecoveryManager.RecoveryRequestExpired.selector);
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    // }

    // function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampMoreThanExpiry()
    //     public
    // {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.warp(block.timestamp + expiry + 1 seconds); // block.timestamp >
    //         // recoveryRequest.executeBefore

    //     vm.expectRevert(IEmailRecoveryManager.RecoveryRequestExpired.selector);
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    // }

    // function test_CompleteRecovery_CompleteRecovery_Succeeds() public {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.warp(block.timestamp + delay);

    //     vm.expectEmit();
    //     emit IEmailRecoveryManager.RecoveryCompleted(accountAddress);
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    // }

    // function test_CompleteRecovery_SucceedsAlmostExpiry() public {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     vm.warp(block.timestamp + expiry - 1 seconds);

    //     vm.expectEmit();
    //     emit IEmailRecoveryManager.RecoveryCompleted(accountAddress);
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    // }
}
