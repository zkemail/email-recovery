// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract AccountHidingRecoveryCommandHandler_extractRecoveredAccountFromRecoveryCommand_Test is
    UnitBase
{
    using Strings for uint256;

    AccountHidingRecoveryCommandHandler public accountHidingRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        accountHidingRecoveryCommandHandler = new AccountHidingRecoveryCommandHandler();
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_FailsWhenHashNotStored() public {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));
        string memory accountHashString = uint256(accountHash).toHexString(32);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountHashString);
        commandParams[1] = abi.encode(recoveryDataHashString);

        address extractedAccount = accountHidingRecoveryCommandHandler
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);

        assertEq(extractedAccount, address(0));
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_FailsWhenUsingAbiEncode() public {
        bytes32 accountHash = keccak256(abi.encode(accountAddress1));
        string memory accountHashString = uint256(accountHash).toHexString(32);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountHashString);
        commandParams[1] = abi.encode(recoveryDataHashString);

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        address extractedAccount = accountHidingRecoveryCommandHandler
            .extractRecoveredAccountFromAcceptanceCommand(commandParams, templateIdx);

        assertEq(extractedAccount, address(0));
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_Succeeds() public {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));
        string memory accountHashString = uint256(accountHash).toHexString(32);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountHashString);
        commandParams[1] = abi.encode(recoveryDataHashString);

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        address extractedAccount = accountHidingRecoveryCommandHandler
            .extractRecoveredAccountFromRecoveryCommand(commandParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
