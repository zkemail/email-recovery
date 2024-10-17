// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_version_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Version_ReturnsVersion() public {
        string memory expectedVersion = "1.0.0";
        string memory actualVersion = emailRecoveryModule.version();
        assertEq(actualVersion, expectedVersion, "Module version should match expected value");
    }
}
