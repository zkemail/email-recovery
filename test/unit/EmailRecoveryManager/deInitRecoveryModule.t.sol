// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianManager } from "src/GuardianManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract EmailRecoveryManager_deInitRecoveryModule_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_DeInitRecoveryModule_RevertWhen_RecoveryInProcess() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        vm.prank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.exposed_deInitRecoveryModule();
    }

    function test_DeInitRecoveryModule_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertTrue(isActivated);

        vm.prank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryDeInitialized(accountAddress1);
        emailRecoveryModule.exposed_deInitRecoveryModule();

        // assert that recovery config has been cleared successfully
        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, 0);
        assertEq(recoveryConfig.expiry, 0);

        // assert that the recovery request has been cleared successfully
        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, "");
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);

        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, address(0));
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);

        // assert that guardian storage has been cleared successfully for guardian 1
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage1.weight, uint256(0));

        // assert that guardian storage has been cleared successfully for guardian 2
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage2.weight, uint256(0));

        // assert that guardian config has been cleared successfully
        GuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, 0);
        assertEq(guardianConfig.totalWeight, 0);
        assertEq(guardianConfig.acceptedWeight, 0);
        assertEq(guardianConfig.threshold, 0);

        isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertFalse(isActivated);
    }

    function test_DeInitRecoveryModule_SucceedsWhen_KillSwitchEnabled() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertTrue(isActivated);

        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        vm.prank(accountAddress1);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryDeInitialized(accountAddress1);
        emailRecoveryModule.exposed_deInitRecoveryModule();

        // assert that recovery config has been cleared successfully
        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, 0);
        assertEq(recoveryConfig.expiry, 0);

        // assert that the recovery request has been cleared successfully
        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, "");
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);

        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, address(0));
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);

        // assert that guardian storage has been cleared successfully for guardian 1
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage1.weight, uint256(0));

        // assert that guardian storage has been cleared successfully for guardian 2
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage2.weight, uint256(0));

        // assert that guardian config has been cleared successfully
        GuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, 0);
        assertEq(guardianConfig.totalWeight, 0);
        assertEq(guardianConfig.acceptedWeight, 0);
        assertEq(guardianConfig.threshold, 0);

        isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertFalse(isActivated);
    }
}
