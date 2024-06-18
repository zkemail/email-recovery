// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_validateAcceptanceSubject_Test is SafeUnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ValidateAcceptanceSubject_RevertWhen_NoSubjectParams() public {
        bytes[] memory emptySubjectParams;

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidSubjectParams.selector);
        safeRecoverySubjectHandler.validateAcceptanceSubject(templateIdx, emptySubjectParams);
    }

    function test_ValidateAcceptanceSubject_RevertWhen_TooManySubjectParams() public {
        bytes[] memory subjectParams = new bytes[](2);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode("extra param");

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidSubjectParams.selector);
        safeRecoverySubjectHandler.validateAcceptanceSubject(templateIdx, subjectParams);
    }

    function test_ValidateAcceptanceSubject_Succeeds() public view {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);

        address account =
            safeRecoverySubjectHandler.validateAcceptanceSubject(templateIdx, subjectParams);
        assertEq(account, accountAddress);
    }
}
