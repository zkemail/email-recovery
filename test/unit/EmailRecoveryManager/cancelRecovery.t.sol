// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_cancelRecovery_Test is UnitBase {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_CancelRecovery_RevertWhen_NoRecoveryInProcess() public {
        vm.startPrank(accountAddress1);
        vm.expectRevert(IEmailRecoveryManager.NoRecoveryInProcess.selector);
        emailRecoveryModule.cancelRecovery();
    }

    function test_CancelRecovery_CannotCancelWrongRecoveryRequest() public {
        address otherAddress = address(99);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        // IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
        //     emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, 0);
        // assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        // assertEq(recoveryRequest.currentWeight, 1);
        // assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.startPrank(otherAddress);
        vm.expectRevert(IEmailRecoveryManager.NoRecoveryInProcess.selector);
        emailRecoveryModule.cancelRecovery();
    }

    function test_CancelRecovery_PartialRequest_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        // IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
        //     emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, 0);
        // assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        // assertEq(recoveryRequest.currentWeight, 1);
        // assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.startPrank(accountAddress1);
        emailRecoveryModule.cancelRecovery();

        // recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, 0);
        // assertEq(recoveryRequest.executeBefore, 0);
        // assertEq(recoveryRequest.currentWeight, 0);
        // assertEq(recoveryRequest.recoveryDataHash, "");
    }

    function test_CancelRecovery_FullRequest_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        // IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
        //     emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        // assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        // assertEq(recoveryRequest.currentWeight, 3);
        // assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryCancelled(accountAddress1);
        emailRecoveryModule.cancelRecovery();

        // recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, 0);
        // assertEq(recoveryRequest.executeBefore, 0);
        // assertEq(recoveryRequest.currentWeight, 0);
        // assertEq(recoveryRequest.recoveryDataHash, "");
    }
}
