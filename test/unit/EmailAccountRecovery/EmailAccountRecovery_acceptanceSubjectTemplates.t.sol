// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";

contract EmailAccountRecoveryTest_acceptanceCommandTemplates is EmailAccountRecoveryBase {
    function setUp() public override {
        super.setUp();
    }

    function testAcceptanceCommandTemplates() public view {
        string[][] memory res = recoveryController.acceptanceCommandTemplates();
        assertEq(res[0][0], "Accept");
        assertEq(res[0][1], "guardian");
        assertEq(res[0][2], "request");
        assertEq(res[0][3], "for");
        assertEq(res[0][4], "{ethAddr}");
    }
}
