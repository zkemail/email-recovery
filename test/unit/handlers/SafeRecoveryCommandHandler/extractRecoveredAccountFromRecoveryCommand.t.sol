// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeUnitBase } from "../../SafeUnitBase.t.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract SafeRecoveryCommandHandler_extractRecoveredAccountFromRecoveryCommand_Test is
    SafeUnitBase
{
    SafeRecoveryCommandHandler public safeRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        safeRecoveryCommandHandler = new SafeRecoveryCommandHandler();
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_Succeeds() public {
        skipIfNotSafeAccountType();
        bytes[] memory commandParams = new bytes[](3);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(newOwner1);
        commandParams[2] = abi.encode(emailRecoveryModuleAddress);

        address extractedAccount = safeRecoveryCommandHandler
            .extractRecoveredAccountFromRecoveryCommand(commandParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
