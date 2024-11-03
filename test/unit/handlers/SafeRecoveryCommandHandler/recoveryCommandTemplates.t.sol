// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeUnitBase } from "../../SafeUnitBase.t.sol";
import { CommandHandlerType } from "../../../Base.t.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract SafeRecoveryCommandHandler_recoveryCommandTemplates_Test is SafeUnitBase {
    SafeRecoveryCommandHandler public safeRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        safeRecoveryCommandHandler = new SafeRecoveryCommandHandler();
    }

    function test_RecoveryCommandTemplates_Succeeds() public {
        skipIfNotSafeAccountType();
        skipIfNotCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);
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
