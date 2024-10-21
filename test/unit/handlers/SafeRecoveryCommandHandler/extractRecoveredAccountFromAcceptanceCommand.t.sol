// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoveryCommandHandler_extractRecoveredAccountFromAcceptanceCommand_Test is
    SafeUnitBase
{
    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromAcceptanceCommand_Succeeds() public {
        skipIfNotSafeAccountType();
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress1);

        address extractedAccount = safeRecoveryCommandHandler
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
