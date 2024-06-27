// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { EnumerableGuardianMap } from "src/libraries/EnumerableGuardianMap.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

// Helper test to associate custom error bytes with error names. Could just write the selector bytes
// in the contracts but this method reduces human error from copying values and also when updating
// errors
contract LogErrorSelectors_Test is Test {
    function test_EmailRecoverySubjectHandler_AssertSelectors() public {
        assertEq(EmailRecoverySubjectHandler.InvalidSubjectParams.selector, bytes4(0xd743ae6c));
        assertEq(EmailRecoverySubjectHandler.InvalidAccount.selector, bytes4(0x6d187b28));
        assertEq(EmailRecoverySubjectHandler.InvalidRecoveryModule.selector, bytes4(0x7f263111));
    }

    function test_SafeRecoverySubjectHandler_AssertSelectors() public {
        assertEq(SafeRecoverySubjectHandler.InvalidSubjectParams.selector, bytes4(0xd743ae6c));
        assertEq(SafeRecoverySubjectHandler.InvalidOldOwner.selector, bytes4(0xa9ab2692));
        assertEq(SafeRecoverySubjectHandler.InvalidNewOwner.selector, bytes4(0x54a56786));
        assertEq(SafeRecoverySubjectHandler.InvalidRecoveryModule.selector, bytes4(0x7f263111));
    }

    function test_IEmailRecoveryManager_AssertSelectors() public {
        assertEq(IEmailRecoveryManager.InvalidSubjectHandler.selector, bytes4(0x436dcac5));
        assertEq(IEmailRecoveryManager.InitializerNotDeployer.selector, bytes4(0x3b141fc4));
        assertEq(IEmailRecoveryManager.InvalidRecoveryModule.selector, bytes4(0x7f263111));
        assertEq(IEmailRecoveryManager.RecoveryInProcess.selector, bytes4(0xf90ea6fc));
        assertEq(IEmailRecoveryManager.SetupAlreadyCalled.selector, bytes4(0xb3af5593));
        assertEq(IEmailRecoveryManager.AccountNotConfigured.selector, bytes4(0x66ecbd6d));
        assertEq(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector, bytes4(0xd5e44d3f));
        assertEq(IEmailRecoveryManager.DelayMoreThanExpiry.selector, bytes4(0x655a4874));
        assertEq(IEmailRecoveryManager.RecoveryWindowTooShort.selector, bytes4(0x12fa0714));
        assertEq(IEmailRecoveryManager.InvalidTemplateIndex.selector, bytes4(0x5abe71c9));
        assertEq(IEmailRecoveryManager.InvalidGuardianStatus.selector, bytes4(0x5689b51a));
        assertEq(IEmailRecoveryManager.InvalidAccountAddress.selector, bytes4(0x401b6ade));
        assertEq(IEmailRecoveryManager.NoRecoveryConfigured.selector, bytes4(0xa66e66b6));
        assertEq(IEmailRecoveryManager.NotEnoughApprovals.selector, bytes4(0x24bcdbea));
        assertEq(IEmailRecoveryManager.DelayNotPassed.selector, bytes4(0xc806ff6e));
        assertEq(IEmailRecoveryManager.RecoveryRequestExpired.selector, bytes4(0x4c2babb1));
        assertEq(IEmailRecoveryManager.InvalidCalldataHash.selector, bytes4(0xf05609de));
        assertEq(IEmailRecoveryManager.NotRecoveryModule.selector, bytes4(0x2f6ef3d6));
    }

    function test_EmailRecoveryModule_AssertSelectors() public {
        assertEq(EmailRecoveryModule.InvalidSelector.selector, bytes4(0x12ba286f));
        assertEq(EmailRecoveryModule.InvalidOnInstallData.selector, bytes4(0x5c223882));
        assertEq(EmailRecoveryModule.InvalidValidator.selector, bytes4(0x11d5c560));
        assertEq(EmailRecoveryModule.MaxValidatorsReached.selector, bytes4(0xed7948d6));
        assertEq(EmailRecoveryModule.NotTrustedRecoveryManager.selector, bytes4(0x38f1b648));
    }

    function test_EnumerableGuardianMap_AssertSelectors() public {
        assertEq(EnumerableGuardianMap.MaxNumberOfGuardiansReached.selector, bytes4(0xbb6c1e93));
        assertEq(EnumerableGuardianMap.TooManyValuesToRemove.selector, bytes4(0xe023c211));
    }

    function test_GuardianUtils_AssertSelectors() public {
        assertEq(GuardianUtils.IncorrectNumberOfWeights.selector, bytes4(0xf4a950ef));
        assertEq(GuardianUtils.ThresholdCannotBeZero.selector, bytes4(0xf4124166));
        assertEq(GuardianUtils.InvalidGuardianAddress.selector, bytes4(0x1b081054));
        assertEq(GuardianUtils.InvalidGuardianWeight.selector, bytes4(0x148f78e0));
        assertEq(GuardianUtils.AddressAlreadyGuardian.selector, bytes4(0xe4e1614e));
        assertEq(GuardianUtils.ThresholdCannotExceedTotalWeight.selector, bytes4(0x717c498a));
        assertEq(GuardianUtils.StatusCannotBeTheSame.selector, bytes4(0x115e823f));
        assertEq(GuardianUtils.SetupNotCalled.selector, bytes4(0xae69115b));
        assertEq(GuardianUtils.UnauthorizedAccountForGuardian.selector, bytes4(0xe4c3248f));
    }

    function test_OwnableValidator_AssertSelectors() public {
        assertEq(OwnableValidator.NotAuthorized.selector, bytes4(0xea8e4eb5));
    }
}
