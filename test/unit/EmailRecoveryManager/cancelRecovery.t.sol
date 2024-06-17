// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_cancelRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_CancelRecovery_CannotCancelWrongRecoveryRequest() public {
    //     address otherAddress = address(99);

    //     acceptGuardian(accountSalt1);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 1);

    //     vm.startPrank(otherAddress);
    //     emailRecoveryManager.cancelRecovery();

    //     recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 1);
    // }

    // function test_CancelRecovery_PartialRequest_Succeeds() public {
    //     acceptGuardian(accountSalt1);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 1);

    //     vm.startPrank(accountAddress);
    //     emailRecoveryManager.cancelRecovery();

    //     recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    // }

    // function test_CancelRecovery_FullRequest_Succeeds() public {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);
    //     handleRecovery(recoveryModuleAddress, accountSalt2);

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
    //     assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
    //     assertEq(recoveryRequest.currentWeight, 3);

    //     vm.startPrank(accountAddress);
    //     emailRecoveryManager.cancelRecovery();

    //     recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    // }
}
