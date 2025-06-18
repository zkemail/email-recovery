// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract GuardianManager_removeGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RemoveGuardian_RevertWhen_KillSwitchEnabled() public {
        address guardian = guardians1[0];

        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.scheduleKillSwitchToggle();
        vm.warp(block.timestamp + 7 days);
        emailRecoveryModule.executeKillSwitchToggle();
        vm.stopPrank();

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.KillSwitchEnabled.selector);
        emailRecoveryModule.removeGuardian(guardian);
    }

    function test_RemoveGuardian_RevertWhen_AlreadyRecovering() public {
        address guardian = guardians1[0];

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.removeGuardian(guardian);
    }

    function test_RemoveGuardian_RevertWhen_AddressNotGuardianForAccount() public {
        address unauthorizedAccount = guardians1[0];

        vm.startPrank(unauthorizedAccount);
        vm.expectRevert(IGuardianManager.AddressNotGuardianForAccount.selector);
        emailRecoveryModule.removeGuardian(guardians1[0]);
    }

    function test_RemoveGuardian_RevertWhen_ThresholdExceedsTotalWeight() public {
        address guardian = guardians1[1]; // guardian 2 weight is 2
        // threshold = 3
        // totalWeight = 4
        // weight = 2

        // Fails if totalWeight - weight < threshold
        // (totalWeight - weight == 4 - 2) = 2
        // (weight < threshold == 2 < 3) = fails

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.ThresholdExceedsTotalWeight.selector,
                totalWeight - guardianWeights[1],
                threshold
            )
        );
        emailRecoveryModule.removeGuardian(guardian);
    }

    function test_RemoveGuardian_Succeeds() public {
        address guardian = guardians1[0]; // guardian 1 weight is 1
        // threshold = 3
        // totalWeight = 4
        // weight = 1

        // Fails if totalWeight - weight < threshold
        // (totalWeight - weight == 4 - 1) = 3
        // (weight < threshold == 3 < 3) = succeeds

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IGuardianManager.RemovedGuardian(accountAddress1, guardian, guardianWeights[0]);
        emailRecoveryModule.removeGuardian(guardian);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress1, guardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage.weight, 0);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, guardians1.length - 1);
        assertEq(guardianConfig.totalWeight, totalWeight - guardianWeights[0]);

        assertEq(guardianConfig.acceptedWeight, 0); // 1 - 1 = 0
        assertEq(guardianConfig.threshold, threshold);
    }

    function test_RemoveGuardian_SucceedsWithAcceptedGuardian() public {
        address guardian = guardians1[0]; // guardian 1 weight is 1
        // threshold = 3
        // totalWeight = 4
        // weight = 1

        // Fails if totalWeight - weight < threshold
        // (totalWeight - weight == 4 - 1) = 3
        // (weight < threshold == 3 < 3) = succeeds

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress); // weight = 1
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress); // weight = 2

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IGuardianManager.RemovedGuardian(accountAddress1, guardian, guardianWeights[0]);
        emailRecoveryModule.removeGuardian(guardian);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress1, guardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage.weight, 0);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, guardians1.length - 1);
        assertEq(guardianConfig.totalWeight, totalWeight - guardianWeights[0]);

        // Accepted weight before guardian is removed = 3
        // acceptedWeight = 3 - 1
        assertEq(guardianConfig.acceptedWeight, 2);
        assertEq(guardianConfig.threshold, threshold);
    }
}
