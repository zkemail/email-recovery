// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_canStartRecoveryRequest_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenThresholdIsZero() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
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

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenThresholdCannotBeMet() public view {
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
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);

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
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

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
