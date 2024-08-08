// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";

contract EmailRecoverySubjectHandler_validateRecoverySubject_Test is UnitBase {
    using Strings for uint256;

    string recoveryDataHashString;
    bytes[] subjectParams;

    function setUp() public override {
        super.setUp();

        recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        subjectParams = new bytes[](2);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(recoveryDataHashString);
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            invalidTemplateIdx, subjectParams
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_NoSubjectParams() public {
        bytes[] memory emptySubjectParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidSubjectParams.selector,
                emptySubjectParams.length,
                2
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, emptySubjectParams
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_TooManySubjectParams() public {
        bytes[] memory longSubjectParams = new bytes[](3);
        longSubjectParams[0] = abi.encode(accountAddress);
        longSubjectParams[1] = abi.encode(recoveryDataHashString);
        longSubjectParams[2] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidSubjectParams.selector,
                longSubjectParams.length,
                2
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, longSubjectParams
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidAccount() public {
        subjectParams[0] = abi.encode(address(0));

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidAccount.selector);
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_ZeroRecoveryDataHash() public {
        subjectParams[1] = abi.encode(bytes32(0));

        vm.expectRevert("invalid hex prefix");
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidHashLength() public {
        subjectParams[1] = abi.encode(uint256(recoveryDataHash).toHexString(33));

        vm.expectRevert("invalid hex string length");
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams
        );
    }

    function test_ValidateRecoverySubject_Succeeds() public view {
        address accountFromEmail = emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams
        );
        assertEq(accountFromEmail, accountAddress);
    }
}
