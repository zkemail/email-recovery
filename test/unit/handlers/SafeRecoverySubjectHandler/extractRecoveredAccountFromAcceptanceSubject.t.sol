// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_extractRecoveredAccountFromAcceptanceSubject_Test is
    SafeUnitBase
{
    SafeRecoverySubjectHandler safeRecoverySubjectHandler;

    function setUp() public override {
        super.setUp();
        safeRecoverySubjectHandler = new SafeRecoverySubjectHandler();
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
