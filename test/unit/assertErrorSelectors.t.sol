// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { EnumerableGuardianMap } from "src/libraries/EnumerableGuardianMap.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";

// Helper test to associate custom error bytes with error names. Could just write the selector bytes
// in the contracts but this method reduces human error from copying values and also when updating
// errors
contract LogErrorSelectors_Test is Test {
    function test_EmailRecoverySubjectHandler_AssertSelectors() public {
        assertEq(EmailRecoverySubjectHandler.InvalidTemplateIndex.selector, bytes4(0x5be77855));
        assertEq(EmailRecoverySubjectHandler.InvalidSubjectParams.selector, bytes4(0x9c6fa025));
        assertEq(EmailRecoverySubjectHandler.InvalidAccount.selector, bytes4(0x6d187b28));
        assertEq(EmailRecoverySubjectHandler.InvalidRecoveryModule.selector, bytes4(0xa01f773d));
    }

    function test_SafeRecoverySubjectHandler_AssertSelectors() public {
        assertEq(SafeRecoverySubjectHandler.InvalidTemplateIndex.selector, bytes4(0x5be77855));
        assertEq(SafeRecoverySubjectHandler.InvalidSubjectParams.selector, bytes4(0x9c6fa025));
        assertEq(SafeRecoverySubjectHandler.InvalidOldOwner.selector, bytes4(0x377abe51));
        assertEq(SafeRecoverySubjectHandler.InvalidNewOwner.selector, bytes4(0x896d9ad0));
        assertEq(SafeRecoverySubjectHandler.InvalidRecoveryModule.selector, bytes4(0xa01f773d));
    }

    function test_IEmailRecoveryManager_AssertSelectors() public {
        assertEq(IEmailRecoveryManager.InvalidVerifier.selector, bytes4(0xbaa3de5f));
        assertEq(IEmailRecoveryManager.InvalidDkimRegistry.selector, bytes4(0x260ce05b));
        assertEq(IEmailRecoveryManager.InvalidEmailAuthImpl.selector, bytes4(0xe98100fb));
        assertEq(IEmailRecoveryManager.InvalidSubjectHandler.selector, bytes4(0x436dcac5));
        assertEq(IEmailRecoveryManager.InitializerNotDeployer.selector, bytes4(0x3b141fc4));
        assertEq(IEmailRecoveryManager.InvalidRecoveryModule.selector, bytes4(0x7f263111));
        assertEq(IEmailRecoveryManager.RecoveryInProcess.selector, bytes4(0xf90ea6fc));
        assertEq(IEmailRecoveryManager.SetupAlreadyCalled.selector, bytes4(0xb3af5593));
        assertEq(IEmailRecoveryManager.AccountNotConfigured.selector, bytes4(0x66ecbd6d));
        assertEq(IEmailRecoveryManager.RecoveryModuleNotAuthorized.selector, bytes4(0xbfa7d2a9));
        assertEq(IEmailRecoveryManager.DelayMoreThanExpiry.selector, bytes4(0xb742a43c));
        assertEq(IEmailRecoveryManager.RecoveryWindowTooShort.selector, bytes4(0x50799cce));
        assertEq(IEmailRecoveryManager.ThresholdExceedsAcceptedWeight.selector, bytes4(0x7c3e983c));
        assertEq(IEmailRecoveryManager.InvalidGuardianStatus.selector, bytes4(0x5689b51a));
        assertEq(IEmailRecoveryManager.InvalidAccountAddress.selector, bytes4(0x401b6ade));
        assertEq(IEmailRecoveryManager.NoRecoveryConfigured.selector, bytes4(0xa66e66b6));
        assertEq(IEmailRecoveryManager.NotEnoughApprovals.selector, bytes4(0x443282f5));
        assertEq(IEmailRecoveryManager.DelayNotPassed.selector, bytes4(0x2f37ae39));
        assertEq(IEmailRecoveryManager.RecoveryRequestExpired.selector, bytes4(0x566ad75e));
        assertEq(IEmailRecoveryManager.InvalidCalldataHash.selector, bytes4(0x54d53855));
        assertEq(IEmailRecoveryManager.NoRecoveryInProcess.selector, bytes4(0x87434f51));
        assertEq(IEmailRecoveryManager.NotRecoveryModule.selector, bytes4(0x2f6ef3d6));
        assertEq(IEmailRecoveryManager.SetupNotCalled.selector, bytes4(0xae69115b));
    }

    function test_EmailRecoveryUniversalFactory_AssertSelectors() public {
        assertEq(EmailRecoveryUniversalFactory.InvalidVerifier.selector, bytes4(0xbaa3de5f));
        assertEq(EmailRecoveryUniversalFactory.InvalidEmailAuthImpl.selector, bytes4(0xe98100fb));
    }

    function test_EmailRecoveryFactory_AssertSelectors() public {
        assertEq(EmailRecoveryFactory.InvalidVerifier.selector, bytes4(0xbaa3de5f));
        assertEq(EmailRecoveryFactory.InvalidEmailAuthImpl.selector, bytes4(0xe98100fb));
    }

    function test_EmailRecoveryModule_AssertSelectors() public {
        assertEq(EmailRecoveryModule.InvalidSelector.selector, bytes4(0x12ba286f));
        assertEq(EmailRecoveryModule.InvalidManager.selector, bytes4(0x34e70f7a));
        assertEq(EmailRecoveryModule.InvalidOnInstallData.selector, bytes4(0x5c223882));
        assertEq(EmailRecoveryModule.InvalidValidator.selector, bytes4(0x11d5c560));
        assertEq(EmailRecoveryModule.NotTrustedRecoveryManager.selector, bytes4(0x38f1b648));
        assertEq(EmailRecoveryModule.RecoveryNotAuthorizedForAccount.selector, bytes4(0xba14d9ef));
    }

    function test_UniversalEmailRecoveryModule_AssertSelectors() public {
        assertEq(UniversalEmailRecoveryModule.InvalidManager.selector, bytes4(0x34e70f7a));
        assertEq(UniversalEmailRecoveryModule.InvalidSelector.selector, bytes4(0x12ba286f));
        assertEq(
            UniversalEmailRecoveryModule.RecoveryModuleNotInitialized.selector, bytes4(0x0b088c23)
        );
        assertEq(UniversalEmailRecoveryModule.InvalidOnInstallData.selector, bytes4(0x5c223882));
        assertEq(UniversalEmailRecoveryModule.InvalidValidator.selector, bytes4(0x11d5c560));
        assertEq(UniversalEmailRecoveryModule.MaxValidatorsReached.selector, bytes4(0xed7948d6));
        assertEq(
            UniversalEmailRecoveryModule.NotTrustedRecoveryManager.selector, bytes4(0x38f1b648)
        );
    }

    function test_EnumerableGuardianMap_AssertSelectors() public {
        assertEq(EnumerableGuardianMap.MaxNumberOfGuardiansReached.selector, bytes4(0xbb6c1e93));
        assertEq(EnumerableGuardianMap.TooManyValuesToRemove.selector, bytes4(0xe023c211));
    }

    function test_GuardianUtils_AssertSelectors() public {
        assertEq(GuardianUtils.IncorrectNumberOfWeights.selector, bytes4(0x166e79bd));
        assertEq(GuardianUtils.ThresholdCannotBeZero.selector, bytes4(0xf4124166));
        assertEq(GuardianUtils.InvalidGuardianAddress.selector, bytes4(0x1af74975));
        assertEq(GuardianUtils.InvalidGuardianWeight.selector, bytes4(0x148f78e0));
        assertEq(GuardianUtils.AddressAlreadyGuardian.selector, bytes4(0xe4e1614e));
        assertEq(GuardianUtils.ThresholdExceedsTotalWeight.selector, bytes4(0xeb912f71));
        assertEq(GuardianUtils.StatusCannotBeTheSame.selector, bytes4(0x7e120711));
        assertEq(GuardianUtils.SetupNotCalled.selector, bytes4(0xae69115b));
        assertEq(GuardianUtils.AddressNotGuardianForAccount.selector, bytes4(0xf3f77749));
    }
}
