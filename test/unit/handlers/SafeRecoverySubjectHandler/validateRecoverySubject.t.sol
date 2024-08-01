// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_validateRecoverySubject_Test is SafeUnitBase {
    using Strings for uint256;

    bytes[] subjectParams;

    function setUp() public override {
        super.setUp();

        subjectParams = new bytes[](4);
        subjectParams[0] = abi.encode(accountAddress1);
        subjectParams[1] = abi.encode(owner1);
        subjectParams[2] = abi.encode(newOwner1);
        subjectParams[3] = abi.encode(recoveryModuleAddress);
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidTemplateIndex() public {
        skipIfNotSafeAccountType();
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidTemplateIndex.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            invalidTemplateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateAcceptanceSubject_RevertWhen_NoSubjectParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory emptySubjectParams;

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidSubjectParams.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, emptySubjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateAcceptanceSubject_RevertWhen_TooManySubjectParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory longSubjectParams = new bytes[](5);
        longSubjectParams[0] = subjectParams[0];
        longSubjectParams[1] = subjectParams[1];
        longSubjectParams[2] = subjectParams[2];
        longSubjectParams[3] = subjectParams[3];
        longSubjectParams[4] = abi.encode("extra param");

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidSubjectParams.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, longSubjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidOldOwner() public {
        skipIfNotSafeAccountType();
        subjectParams[1] = abi.encode(address(0));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidOldOwner.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_ZeroNewOwner() public {
        skipIfNotSafeAccountType();
        subjectParams[2] = abi.encode(address(0));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidNewOwner.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidNewOwner() public {
        skipIfNotSafeAccountType();
        subjectParams[2] = abi.encode(owner1);

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidNewOwner.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleAddressIsZero() public {
        skipIfNotSafeAccountType();
        subjectParams[3] = abi.encode(address(0));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidRecoveryModule.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleNotEqualToExpectedAddress()
        public
    {
        skipIfNotSafeAccountType();
        subjectParams[3] = abi.encode(address(1));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidRecoveryModule.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_Succeeds() public {
        skipIfNotSafeAccountType();
        address accountFromEmail = safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
        assertEq(accountFromEmail, accountAddress1);
    }
}
