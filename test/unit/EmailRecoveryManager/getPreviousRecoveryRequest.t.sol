// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_getPreviousRecoveryRequest_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_GetPreviousRecoveryRequest_SucceedsAfterCompleteRecovery() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        vm.warp(block.timestamp + delay);

        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);

        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
    }

    function test_GetPreviousRecoveryRequest_SucceedsAfterCancelExpiredRecovery() public {
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        vm.warp(block.timestamp + expiry);

        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[1]);
        assertEq(
            previousRecoveryRequest.cancelRecoveryCooldown,
            block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN()
        );
    }
}
