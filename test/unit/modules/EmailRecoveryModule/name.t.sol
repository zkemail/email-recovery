// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_name_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Name_ReturnsName() public view {
        string memory expectedName = "ZKEmail.EmailRecoveryModule";
        string memory actualName = emailRecoveryModule.name();
        assertEq(actualName, expectedName, "Module name should match expected value");
    }
}
