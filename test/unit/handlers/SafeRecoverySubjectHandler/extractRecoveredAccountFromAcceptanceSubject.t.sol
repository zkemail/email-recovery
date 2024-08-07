// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_extractRecoveredAccountFromAcceptanceSubject_Test is
    SafeUnitBase
{
    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromAcceptanceSubject_Succeeds() public {
        skipIfNotSafeAccountType();
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress1);

        address extractedAccount = safeRecoverySubjectHandler
            .extractRecoveredAccountFromAcceptanceSubject(subjectParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
