// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_extractRecoveredAccountFromRecoverySubject_Test is
    SafeUnitBase
{
    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromRecoverySubject_Succeeds() public view {
        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress1);
        subjectParams[1] = abi.encode(newOwner1);
        subjectParams[2] = abi.encode(recoveryModuleAddress);

        address extractedAccount = safeRecoverySubjectHandler
            .extractRecoveredAccountFromRecoverySubject(subjectParams, templateIdx);
        assertEq(extractedAccount, accountAddress1);
    }
}
