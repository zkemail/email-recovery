// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_cancelRecovery_Test is UnitBase {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_CancelExpiredRecovery_RevertWhen_NoRecoveryInProcess() public {
        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.NoRecoveryInProcess.selector);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress);
    }

    function test_CancelExpiredRecovery_CannotCancelNotStartedRecoveryRequest() public {
        address otherAddress = address(99);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, bytes32(0));

        vm.startPrank(otherAddress);
        vm.expectRevert(IEmailRecoveryManager.NoRecoveryInProcess.selector);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress);
    }

    function test_CancelExpiredRecovery_CannotCancelNotExpiredRequest() public {
        address otherAddress = address(99);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.startPrank(otherAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.NotCancelUnexpiredRequest.selector,
                accountAddress,
                block.timestamp,
                block.timestamp + expiry
            )
        );
        emailRecoveryModule.cancelExpiredRecovery(accountAddress);
    }

    function test_CancelExpiredRecovery_PartialRequest_Succeeds() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.warp(block.timestamp + expiry);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");
    }

    function test_CancelExpiredRecovery_FullRequest_Succeeds() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds + 1 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);
        handleRecovery(recoveryDataHash, accountSalt2);

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.warp(block.timestamp + expiry);
        address otherAddress = address(99);
        vm.startPrank(otherAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");
    }
}
