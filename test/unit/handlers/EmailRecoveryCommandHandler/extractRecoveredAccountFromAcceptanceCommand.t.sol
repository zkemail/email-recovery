// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoveryCommandHandler_extractRecoveredAccountFromAcceptanceCommand_Test is
    UnitBase
{
    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromAcceptanceCommand_Succeeds() public view {
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress);

        address extractedAccount = emailRecoveryHandler.extractRecoveredAccountFromAcceptanceCommand(
            commandParams, templateIdx
        );
        assertEq(extractedAccount, accountAddress);
    }
}