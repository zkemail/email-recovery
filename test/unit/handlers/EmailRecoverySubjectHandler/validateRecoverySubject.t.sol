// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";

contract EmailRecoverySubjectHandler_validateRecoverySubject_Test is UnitBase {
    using Strings for uint256;

    string calldataHashString;
    bytes[] subjectParams;

    function setUp() public override {
        super.setUp();

        calldataHashString = uint256(calldataHash).toHexString(32);

        subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(recoveryModuleAddress);
        subjectParams[2] = abi.encode(calldataHashString);
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            invalidTemplateIdx, subjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_NoSubjectParams() public {
        bytes[] memory emptySubjectParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidSubjectParams.selector,
                emptySubjectParams.length,
                3
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, emptySubjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_TooManySubjectParams() public {
        bytes[] memory longSubjectParams = new bytes[](4);
        longSubjectParams[0] = abi.encode(accountAddress);
        longSubjectParams[1] = abi.encode(recoveryModuleAddress);
        longSubjectParams[2] = abi.encode(calldataHashString);
        longSubjectParams[3] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidSubjectParams.selector,
                longSubjectParams.length,
                3
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, longSubjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidAccount() public {
        subjectParams[0] = abi.encode(address(0));

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidAccount.selector);
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleAddressIsZero() public {
        subjectParams[1] = abi.encode(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidRecoveryModule.selector, address(0)
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleNotEqualToExpectedAddress()
        public
    {
        subjectParams[1] = abi.encode(address(1));

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidRecoveryModule.selector, address(1)
            )
        );
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_ZeroCalldataHash() public {
        subjectParams[2] = abi.encode(bytes32(0));

        vm.expectRevert("invalid hex prefix");
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidHashLength() public {
        subjectParams[2] = abi.encode(uint256(calldataHash).toHexString(33));

        vm.expectRevert("invalid hex string length");
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, recoveryModuleAddress
        );
    }

    function test_ValidateRecoverySubject_Succeeds() public view {
        address accountFromEmail = emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, recoveryModuleAddress
        );
        assertEq(accountFromEmail, accountAddress);
    }
}
