// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoveryCommandHandler_recoveryCommandTemplates_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RecoveryCommandTemplates_Succeeds() public view {
        string[][] memory templates = emailRecoveryHandler.recoveryCommandTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 7);
        assertEq(templates[0][0], "Recover");
        assertEq(templates[0][1], "account");
        assertEq(templates[0][2], "{ethAddr}");
        assertEq(templates[0][3], "using");
        assertEq(templates[0][4], "recovery");
        assertEq(templates[0][5], "hash");
        assertEq(templates[0][6], "{string}");
    }
}
