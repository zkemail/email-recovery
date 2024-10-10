// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeUnitBase } from "../../SafeUnitBase.t.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract SafeRecoveryCommandHandler_acceptanceCommandTemplates_Test is SafeUnitBase {
    SafeRecoveryCommandHandler public safeRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        safeRecoveryCommandHandler = new SafeRecoveryCommandHandler();
    }

    function test_AcceptanceCommandTemplates_Succeeds() public {
        skipIfNotSafeAccountType();
        string[][] memory templates = safeRecoveryCommandHandler.acceptanceCommandTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 5);
        assertEq(templates[0][0], "Accept");
        assertEq(templates[0][1], "guardian");
        assertEq(templates[0][2], "request");
        assertEq(templates[0][3], "for");
        assertEq(templates[0][4], "{ethAddr}");
    }
}
