// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_canStartRecoveryRequest_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenThresholdCannotBeMet() public {
        bool canStartRecoveryRequest = emailRecoveryModule.canStartRecoveryRequest(accountAddress);

        // Checking accepted weight is what we expect for this test case
        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            IEmailRecoveryManager(emailRecoveryManager).getGuardianConfig(accountAddress);

        // No guardians have accepted
        assertFalse(canStartRecoveryRequest);
        assertFalse(guardianConfig.acceptedWeight >= guardianConfig.threshold);
    }

    function test_CanStartRecoveryRequest_ReturnsTrue_WhenThresholdIsHigherThanWeight() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        acceptGuardian(accountSalt3);

        bool canStartRecoveryRequest = emailRecoveryModule.canStartRecoveryRequest(accountAddress);

        // Checking accepted weight is what we expect for this test case
        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            IEmailRecoveryManager(emailRecoveryManager).getGuardianConfig(accountAddress);

        // Enough guardians have accepted so that accepted weight is higher than the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(guardianConfig.acceptedWeight > guardianConfig.threshold);
    }

    function test_CanStartRecoveryRequest_ReturnsTrue_WhenThresholdIsEqualToWeight() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);

        bool canStartRecoveryRequest = emailRecoveryModule.canStartRecoveryRequest(accountAddress);

        // Checking accepted weight is what we expect for this test case
        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            IEmailRecoveryManager(emailRecoveryManager).getGuardianConfig(accountAddress);

        // Enough guardians have accepted so that accepted weight is equal to the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(guardianConfig.acceptedWeight == guardianConfig.threshold);
    }
}
