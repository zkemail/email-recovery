// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoveryCommandHandler_extractRecoveredAccountFromRecoveryCommand_Test is UnitBase {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromRecoveryCommand_Succeeds() public view {
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](3);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(emailRecoveryModuleAddress);
        commandParams[2] = abi.encode(recoveryDataHashString);

        address extractedAccount = emailRecoveryHandler.extractRecoveredAccountFromRecoveryCommand(
            commandParams, templateIdx
        );
        assertEq(extractedAccount, accountAddress1);
    }
}
