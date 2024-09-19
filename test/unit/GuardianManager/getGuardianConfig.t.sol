// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_getGuardianConfig_Test is UnitBase {
    address public newGuardian = address(1);
    uint256 public newGuardianWeight = 1;

    uint256 public expectedGuardianCount;
    uint256 public expectedTotalWeight;
    uint256 public expectedAcceptedWeight;
    uint256 public expectedThreshold;

    function setUp() public override {
        super.setUp();

        expectedGuardianCount = guardians1.length + 1;
        expectedTotalWeight = totalWeight + newGuardianWeight;
        expectedAcceptedWeight = 0; // no guardians accepted
        expectedThreshold = threshold;

        vm.startPrank(accountAddress1);
        emailRecoveryModule.addGuardian(newGuardian, newGuardianWeight);
        vm.stopPrank();
    }

    function test_GetGuardianConfig_Succeeds() public view {
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.acceptedWeight, expectedAcceptedWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
