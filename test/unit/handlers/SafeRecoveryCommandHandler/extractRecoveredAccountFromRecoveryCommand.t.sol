// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoveryCommandHandler_extractRecoveredAccountFromRecoveryCommand_Test is
    SafeUnitBase
{
    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_Succeeds() public {
        skipIfNotSafeAccountType();
        bytes[] memory commandParams = new bytes[](3);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(newOwner1);
        commandParams[2] = abi.encode(recoveryModuleAddress);

        address extractedAccount = safeRecoveryCommandHandler
            .extractRecoveredAccountFromRecoveryCommand(commandParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
