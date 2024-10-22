// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract AccountHidingRecoveryCommandHandler_recoveryCommandTemplates_Test is UnitBase {
    AccountHidingRecoveryCommandHandler public accountHidingRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        accountHidingRecoveryCommandHandler = new AccountHidingRecoveryCommandHandler();
    }

    function test_RecoveryCommandTemplates_Succeeds() public view {
        string[][] memory templates = accountHidingRecoveryCommandHandler.recoveryCommandTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 7);
        assertEq(templates[0][0], "Recover");
        assertEq(templates[0][1], "account");
        assertEq(templates[0][2], "{string}");
        assertEq(templates[0][3], "using");
        assertEq(templates[0][4], "recovery");
        assertEq(templates[0][5], "hash");
        assertEq(templates[0][6], "{string}");
    }
}
