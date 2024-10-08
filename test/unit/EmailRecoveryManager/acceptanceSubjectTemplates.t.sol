// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { CommandHandlerType } from "../../Base.t.sol";

contract EmailRecoveryManager_acceptanceCommandTemplates_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_AcceptanceCommandTemplates_Succeeds() public {
        skipIfNotCommandHandlerType(CommandHandlerType.EmailRecoveryCommandHandler);
        string[][] memory templates = emailRecoveryModule.acceptanceCommandTemplates();

        assertEq(templates.length, 1);
        assertEq(templates[0].length, 5);
        assertEq(templates[0][0], "Accept");
        assertEq(templates[0][1], "guardian");
        assertEq(templates[0][2], "request");
        assertEq(templates[0][3], "for");
        assertEq(templates[0][4], "{ethAddr}");
    }
}
