// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_acceptanceSubjectTemplates_Test is SafeUnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_AcceptanceSubjectTemplates_Succeeds() public view {
        string[][] memory templates = safeRecoverySubjectHandler.acceptanceSubjectTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 5);
        assertEq(templates[0][0], "Accept");
        assertEq(templates[0][1], "guardian");
        assertEq(templates[0][2], "request");
        assertEq(templates[0][3], "for");
        assertEq(templates[0][4], "{ethAddr}");
    }
}
