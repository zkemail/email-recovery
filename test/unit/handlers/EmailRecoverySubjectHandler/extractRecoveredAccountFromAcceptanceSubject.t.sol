// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoverySubjectHandler_extractRecoveredAccountFromAcceptanceSubject_Test is
    UnitBase
{
    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromAcceptanceSubject_Succeeds() public view {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);

        address extractedAccount = emailRecoveryHandler.extractRecoveredAccountFromAcceptanceSubject(
            subjectParams, templateIdx
        );
        assertEq(extractedAccount, accountAddress);
    }
}
