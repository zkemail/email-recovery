// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";

contract GuardianManager_getAllGuardians_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_getAllGuardians_Succeeds() public {
        address[] memory guardians = emailRecoveryModule.getAllGuardians(accountAddress1);
        assertEq(guardians.length, guardians1.length);
        assertEq(guardians[0], guardians1[0]);
        assertEq(guardians[1], guardians1[1]);
        assertEq(guardians[2], guardians1[2]);
    }
}
