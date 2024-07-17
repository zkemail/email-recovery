// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_validateAcceptanceSubject_Test is SafeUnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ValidateAcceptanceSubject_RevertWhen_InvalidTemplateIndex() public {
        skipIfNotSafeAccountType();
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress1);
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidTemplateIndex.selector);
        safeRecoverySubjectHandler.validateAcceptanceSubject(invalidTemplateIdx, subjectParams);
    }

    function test_ValidateAcceptanceSubject_RevertWhen_NoSubjectParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory emptySubjectParams;

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidSubjectParams.selector);
        safeRecoverySubjectHandler.validateAcceptanceSubject(templateIdx, emptySubjectParams);
    }

    function test_ValidateAcceptanceSubject_RevertWhen_TooManySubjectParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory subjectParams = new bytes[](2);
        subjectParams[0] = abi.encode(accountAddress1);
        subjectParams[1] = abi.encode("extra param");

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidSubjectParams.selector);
        safeRecoverySubjectHandler.validateAcceptanceSubject(templateIdx, subjectParams);
    }

    function test_ValidateAcceptanceSubject_Succeeds() public {
        skipIfNotSafeAccountType();
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress1);

        address account =
            safeRecoverySubjectHandler.validateAcceptanceSubject(templateIdx, subjectParams);
        assertEq(account, accountAddress1);
    }
}
