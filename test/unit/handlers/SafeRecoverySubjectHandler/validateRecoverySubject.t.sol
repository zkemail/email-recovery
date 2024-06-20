// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_validateRecoverySubject_Test is SafeUnitBase {
    using Strings for uint256;

    string calldataHashString;
    bytes[] subjectParams;

    function setUp() public override {
        super.setUp();

        calldataHashString = uint256(calldataHash).toHexString(32);
        subjectParams = new bytes[](4);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(owner);
        subjectParams[2] = abi.encode(newOwner);
        subjectParams[3] = abi.encode(recoveryModuleAddress);
    }

    function test_ValidateAcceptanceSubject_RevertWhen_NoSubjectParams() public {
        bytes[] memory emptySubjectParams;

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidSubjectParams.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, emptySubjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateAcceptanceSubject_RevertWhen_TooManySubjectParams() public {
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
        subjectParams[1] = abi.encode(address(0));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidOldOwner.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_InvalidNewOwner() public {
        subjectParams[2] = abi.encode(address(0));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidNewOwner.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleAddressIsZero() public {
        subjectParams[3] = abi.encode(address(0));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidRecoveryModule.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_RevertWhen_RecoveryModuleNotEqualToExpectedAddress()
        public
    {
        subjectParams[3] = abi.encode(address(1));

        vm.expectRevert(SafeRecoverySubjectHandler.InvalidRecoveryModule.selector);
        safeRecoverySubjectHandler.validateRecoverySubject(
            templateIdx, subjectParams, emailRecoveryManagerAddress
        );
    }

    function test_ValidateRecoverySubject_Succeeds() public view {
        (address account, string memory calldataHash) = safeRecoverySubjectHandler
            .validateRecoverySubject(templateIdx, subjectParams, emailRecoveryManagerAddress);
        assertEq(account, accountAddress);
        assertEq(calldataHash, calldataHashString);
    }
}
