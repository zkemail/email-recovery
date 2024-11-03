// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

contract EmailRecoveryCommandHandler_extractRecoveredAccountFromRecoveryCommand_Test is UnitBase {
    using Strings for uint256;

    EmailRecoveryCommandHandler public emailRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        emailRecoveryCommandHandler = new EmailRecoveryCommandHandler();
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_Succeeds() public view {
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(recoveryDataHashString);

        address extractedAccount = emailRecoveryCommandHandler
            .extractRecoveredAccountFromRecoveryCommand(commandParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
