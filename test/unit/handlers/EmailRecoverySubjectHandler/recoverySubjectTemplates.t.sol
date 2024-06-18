// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoverySubjectHandler_recoverySubjectTemplates_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RecoverySubjectTemplates_Succeeds() public view {
        string[][] memory templates = emailRecoveryHandler.recoverySubjectTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 11);
        assertEq(templates[0][0], "Recover");
        assertEq(templates[0][1], "account");
        assertEq(templates[0][2], "{ethAddr}");
        assertEq(templates[0][3], "via");
        assertEq(templates[0][4], "recovery");
        assertEq(templates[0][5], "module");
        assertEq(templates[0][6], "{ethAddr}");
        assertEq(templates[0][7], "using");
        assertEq(templates[0][8], "recovery");
        assertEq(templates[0][9], "hash");
        assertEq(templates[0][10], "{string}");
    }
}
