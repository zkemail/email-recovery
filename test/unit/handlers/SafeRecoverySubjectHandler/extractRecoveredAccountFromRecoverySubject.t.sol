// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_extractRecoveredAccountFromRecoverySubject_Test is
    SafeUnitBase
{
    using Strings for uint256;

    SafeRecoverySubjectHandler safeRecoverySubjectHandler;

    function setUp() public override {
        super.setUp();
        safeRecoverySubjectHandler = new SafeRecoverySubjectHandler();
    }

    function test_ExtractRecoveredAccountFromRecoverySubject_Succeeds() public view {
        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);

        address extractedAccount = safeRecoverySubjectHandler
            .extractRecoveredAccountFromRecoverySubject(subjectParams, templateIdx);
        assertEq(extractedAccount, accountAddress);
    }
}
