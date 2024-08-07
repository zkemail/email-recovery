// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract GuardianManager_getGuardian_Test is UnitBase {
    address newGuardian = address(1);
    uint256 newGuardianWeight = 1;

    function setUp() public override {
        super.setUp();

        vm.startPrank(accountAddress);
        emailRecoveryModule.addGuardian(newGuardian, newGuardianWeight);
        vm.stopPrank();
    }

    function test_GetGuardian_Succeeds() public {
        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress, newGuardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage.weight, newGuardianWeight);
    }
}
