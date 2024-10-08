// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

contract EmailRecoveryCommandHandler_extractRecoveredAccountFromAcceptanceCommand_Test is
    UnitBase
{
    EmailRecoveryCommandHandler public emailRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        emailRecoveryCommandHandler = new EmailRecoveryCommandHandler();
    }

    function test_ExtractRecoveredAccountFromAcceptanceCommand_Succeeds() public view {
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress1);

        address extractedAccount = emailRecoveryCommandHandler
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
