// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianManager } from "src/GuardianManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract EmailRecoveryManager_deInitRecoveryModuleWithAddress_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_DeInitRecoveryModuleWithAddress_RevertWhen_RecoveryInProcess() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);

        vm.prank(accountAddress);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.exposed_deInitRecoveryModule(accountAddress);
    }

    function test_DeInitRecoveryModuleWithAddress_Succeeds() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertTrue(isActivated);

        vm.prank(accountAddress);
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryDeInitialized(accountAddress);
        emailRecoveryModule.exposed_deInitRecoveryModule(accountAddress);

        // assert that recovery config has been cleared successfully
        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            emailRecoveryModule.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.delay, 0);
        assertEq(recoveryConfig.expiry, 0);

        // assert that the recovery request has been cleared successfully
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, "");

        // assert that guardian storage has been cleared successfully for guardian 1
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage1.weight, uint256(0));

        // assert that guardian storage has been cleared successfully for guardian 2
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress, guardian2);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage2.weight, uint256(0));

        // assert that guardian config has been cleared successfully
        GuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, 0);
        assertEq(guardianConfig.totalWeight, 0);
        assertEq(guardianConfig.acceptedWeight, 0);
        assertEq(guardianConfig.threshold, 0);

        isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertFalse(isActivated);
    }
}
