// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { SafeNativeIntegrationBase } from
    "../../../integration/SafeRecovery/SafeNativeIntegrationBase.t.sol";

contract SafeEmailRecoveryModule_canStartRecoveryRequest_Test is SafeNativeIntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenThresholdIsZero() public {
        skipIfNotSafeAccountType();

        bool canStartRecoveryRequest = emailRecoveryModule.canStartRecoveryRequest(accountAddress1);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);

        // Threshold is zero
        assertFalse(canStartRecoveryRequest);
        assertFalse(
            guardianConfig.threshold > 0
                && guardianConfig.acceptedWeight >= guardianConfig.threshold
        );
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenThresholdCannotBeMet() public {
        skipIfNotSafeAccountType();
        vm.startPrank(accountAddress1);
        emailRecoveryModule.configureSafeRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        bool canStartRecoveryRequest = emailRecoveryModule.canStartRecoveryRequest(accountAddress1);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);

        // No guardians have accepted
        assertFalse(canStartRecoveryRequest);
        assertFalse(
            guardianConfig.threshold > 0
                && guardianConfig.acceptedWeight >= guardianConfig.threshold
        );
    }

    function test_CanStartRecoveryRequest_ReturnsTrue_WhenWeightIsHigherThanThreshold() public {
        skipIfNotSafeAccountType();
        vm.startPrank(accountAddress1);
        emailRecoveryModule.configureSafeRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress, accountSalt1
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            accountAddress1, guardians1[1], emailRecoveryModuleAddress, accountSalt2
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            accountAddress1, guardians1[2], emailRecoveryModuleAddress, accountSalt3
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);

        bool canStartRecoveryRequest = emailRecoveryModule.canStartRecoveryRequest(accountAddress1);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);

        // Enough guardians have accepted so that accepted weight is higher than the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(
            guardianConfig.threshold > 0 && guardianConfig.acceptedWeight > guardianConfig.threshold
        );
    }

    function test_CanStartRecoveryRequest_ReturnsTrue_WhenThresholdIsEqualToWeight() public {
        skipIfNotSafeAccountType();
        vm.startPrank(accountAddress1);
        emailRecoveryModule.configureSafeRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress, accountSalt1
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            accountAddress1, guardians1[1], emailRecoveryModuleAddress, accountSalt2
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);

        bool canStartRecoveryRequest = emailRecoveryModule.canStartRecoveryRequest(accountAddress1);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);

        // Enough guardians have accepted so that accepted weight is equal to the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(
            guardianConfig.threshold > 0
                && guardianConfig.acceptedWeight == guardianConfig.threshold
        );
    }
}
