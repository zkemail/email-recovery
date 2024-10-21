// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract AccountHidingRecoveryCommandHandler_extractRecoveredAccountFromAcceptanceCommand_Test is
    UnitBase
{
    using Strings for uint256;

    AccountHidingRecoveryCommandHandler public accountHidingRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        accountHidingRecoveryCommandHandler = new AccountHidingRecoveryCommandHandler();
    }

    function test_ExtractRecoveredAccountFromAcceptanceCommand_FailsWhenHashNotStored()
        public
        view
    {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));

        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(uint256(accountHash).toHexString(32));

        address extractedAccount = accountHidingRecoveryCommandHandler
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);

        assertEq(extractedAccount, address(0));
    }

    function test_ExtractRecoveredAccountFromAcceptanceCommand_FailsWhenUsingAbiEncode() public {
        bytes32 accountHash = keccak256(abi.encode(accountAddress1));

        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(uint256(accountHash).toHexString(32));

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        address extractedAccount = accountHidingRecoveryCommandHandler
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);

        assertEq(extractedAccount, address(0));
    }

    function test_ExtractRecoveredAccountFromAcceptanceCommand_Succeeds() public {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));

        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(uint256(accountHash).toHexString(32));

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        address extractedAccount = accountHidingRecoveryCommandHandler
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);

        assertEq(extractedAccount, accountAddress1);
    }
}
