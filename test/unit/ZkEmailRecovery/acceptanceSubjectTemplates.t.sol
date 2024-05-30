// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract ZkEmailRecovery_acceptanceSubjectTemplates_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_AcceptanceSubjectTemplates_Succeeds() public view {
        string[][] memory templates = zkEmailRecovery.acceptanceSubjectTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 5);
        assertEq(templates[0][0], "Accept");
        assertEq(templates[0][1], "guardian");
        assertEq(templates[0][2], "request");
        assertEq(templates[0][3], "for");
        assertEq(templates[0][4], "{ethAddr}");
    }
}
