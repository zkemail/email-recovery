// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { CommandHandlerType } from "../../Base.t.sol";

contract EmailRecoveryManager_extractRecoveredAccountFromRecoveryCommand_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_FailsWithAbiEncodePacked() public {
        skipIfNotCommandHandlerType(CommandHandlerType.EmailRecoveryCommandHandler);

        address account = address(0x1234567890123456789012345678901234567890);
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encodePacked(account);

        vm.expectRevert();
        emailRecoveryModule.extractRecoveredAccountFromRecoveryCommand(commandParams, 0);
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_Succeeds() public {
        skipIfNotCommandHandlerType(CommandHandlerType.EmailRecoveryCommandHandler);

        address expectedAccount = address(1);
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(expectedAccount);

        address extractedAccount =
            emailRecoveryModule.extractRecoveredAccountFromRecoveryCommand(commandParams, 0);
        assertEq(
            extractedAccount, expectedAccount, "Extracted account should match expected account"
        );
    }
}
