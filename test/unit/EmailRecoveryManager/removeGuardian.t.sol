// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract EmailRecoveryManager_removeGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RemoveGuardian_RevertWhen_AlreadyRecovering() public {
        address guardian = guardian1;

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.removeGuardian(guardian);
    }

    function test_RemoveGuardian_Succeeds() public {
        address guardian = guardian1; // guardian 1 weight is 1
        // threshold = 3
        // totalWeight = 4
        // weight = 1

        // Fails if totalWeight - weight < threshold
        // (totalWeight - weight == 4 - 1) = 3
        // (weight < threshold == 3 < 3) = succeeds

        acceptGuardian(accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit IGuardianManager.RemovedGuardian(accountAddress, guardian, guardianWeights[0]);
        emailRecoveryModule.removeGuardian(guardian);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress, guardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage.weight, 0);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length - 1);
        assertEq(guardianConfig.totalWeight, totalWeight - guardianWeights[0]);
        assertEq(guardianConfig.acceptedWeight, 0); // 1 - 1 = 0
        assertEq(guardianConfig.threshold, threshold);
    }
}
