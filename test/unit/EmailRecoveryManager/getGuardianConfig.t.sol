// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_getGuardianConfig_Test is UnitBase {
    address newGuardian = address(1);
    uint256 newGuardianWeight = 1;

    uint256 expectedGuardianCount;
    uint256 expectedTotalWeight;
    uint256 expectedThreshold;

    function setUp() public override {
        super.setUp();

        expectedGuardianCount = guardians.length + 1;
        expectedTotalWeight = totalWeight + newGuardianWeight;
        expectedThreshold = threshold;

        vm.startPrank(accountAddress);
        emailRecoveryManager.addGuardian(newGuardian, newGuardianWeight);
        vm.stopPrank();
    }

    function test_GetGuardianConfig_Succeeds() public {
        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        console2.log(expectedGuardianCount);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
