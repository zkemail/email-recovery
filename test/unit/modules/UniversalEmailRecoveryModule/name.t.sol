// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_name_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Name_ReturnsName() public view {
        string memory expectedName = "ZKEmail.UniversalEmailRecoveryModule";
        string memory actualName = emailRecoveryModule.name();
        assertEq(actualName, expectedName, "Module name should match expected value");
    }
}
