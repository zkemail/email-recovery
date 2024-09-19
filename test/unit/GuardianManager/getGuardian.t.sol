// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract GuardianManager_getGuardian_Test is UnitBase {
    address public newGuardian = address(1);
    uint256 public newGuardianWeight = 1;

    function setUp() public override {
        super.setUp();

        vm.startPrank(accountAddress1);
        emailRecoveryModule.addGuardian(newGuardian, newGuardianWeight);
        vm.stopPrank();
    }

    function test_GetGuardian_Succeeds() public view {
        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress1, newGuardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage.weight, newGuardianWeight);
    }
}
