// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoverySubjectHandler_validateAcceptanceSubject_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ValidateAcceptanceSubject_RevertWhen_NoSubjectParams() public {
        bytes[] memory emptySubjectParams;

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidSubjectParams.selector);
        emailRecoveryHandler.validateAcceptanceSubject(templateIdx, emptySubjectParams);
    }

    function test_ValidateAcceptanceSubject_RevertWhen_TooManySubjectParams() public {
        bytes[] memory subjectParams = new bytes[](2);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode("extra param");

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidSubjectParams.selector);
        emailRecoveryHandler.validateAcceptanceSubject(templateIdx, subjectParams);
    }

    function test_ValidateAcceptanceSubject_Succeeds() public view {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);

        address account = emailRecoveryHandler.validateAcceptanceSubject(templateIdx, subjectParams);
        assertEq(account, accountAddress);
    }
}
