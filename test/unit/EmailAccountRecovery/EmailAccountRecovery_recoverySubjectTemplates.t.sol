// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";

contract EmailAccountRecoveryTest_recoveryCommandTemplates is EmailAccountRecoveryBase {
    function setUp() public override {
        super.setUp();
    }

    function testRecoveryCommandTemplates() public view {
        string[][] memory res = recoveryController.recoveryCommandTemplates();
        assertEq(res[0][0], "Set");
        assertEq(res[0][1], "the");
        assertEq(res[0][2], "new");
        assertEq(res[0][3], "signer");
        assertEq(res[0][4], "of");
        assertEq(res[0][5], "{ethAddr}");
        assertEq(res[0][6], "to");
        assertEq(res[0][7], "{ethAddr}");
    }
}
