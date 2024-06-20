// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
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

    function test_ValidateRecoverySubject_RevertWhen_NoSubjectParams() public {
        bytes[] memory emptySubjectParams;

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidSubjectParams.selector);
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, emptySubjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_TooManySubjectParams() public {
        bytes[] memory longSubjectParams = new bytes[](4);
        longSubjectParams[0] = abi.encode(accountAddress);
        longSubjectParams[1] = abi.encode(recoveryModuleAddress);
        longSubjectParams[2] = abi.encode(calldataHashString);
        longSubjectParams[3] = abi.encode("extra param");

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidSubjectParams.selector);
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, longSubjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidAccount() public {
        subjectParams[0] = abi.encode(address(0));

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidAccount.selector);
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleAddressIsZero() public {
        subjectParams[1] = abi.encode(address(0));

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidRecoveryModule.selector);
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleNotEqualToExpectedAddress()
        public
    {
        subjectParams[1] = abi.encode(address(1));

        vm.expectRevert(EmailRecoverySubjectHandler.InvalidRecoveryModule.selector);
        emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_Succeeds() public view {
        (address account, string memory calldataHash) = emailRecoveryHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
        assertEq(account, accountAddress);
        assertEq(calldataHashString, calldataHash);
    }
}
