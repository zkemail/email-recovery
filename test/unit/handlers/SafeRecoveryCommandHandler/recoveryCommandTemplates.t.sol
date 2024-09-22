// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoveryCommandHandler_recoveryCommandTemplates_Test is SafeUnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RecoveryCommandTemplates_Succeeds() public {
        skipIfNotSafeAccountType();
        string[][] memory templates = safeRecoveryCommandHandler.recoveryCommandTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 11);
        assertEq(templates[0][0], "Recover");
        assertEq(templates[0][1], "account");
        assertEq(templates[0][2], "{ethAddr}");
        assertEq(templates[0][3], "from");
        assertEq(templates[0][4], "old");
        assertEq(templates[0][5], "owner");
        assertEq(templates[0][6], "{ethAddr}");
        assertEq(templates[0][7], "to");
        assertEq(templates[0][8], "new");
        assertEq(templates[0][9], "owner");
        assertEq(templates[0][10], "{ethAddr}");
    }
}
