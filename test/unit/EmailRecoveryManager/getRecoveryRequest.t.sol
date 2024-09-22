// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_getRecoveryRequest_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_GetRecoveryRequest_Succeeds() public {
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
    }
}
