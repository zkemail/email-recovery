// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract UniversalEmailRecoveryModule_canStartRecoveryRequest_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenThresholdCannotBeMet() public view {
        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress1, validatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        bool contains =
            emailRecoveryModule.workaround_validatorsContains(accountAddress1, validatorAddress);

        // No guardians have accepted
        assertFalse(canStartRecoveryRequest);
        assertFalse(guardianConfig.acceptedWeight >= guardianConfig.threshold);
        assertTrue(contains);
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenValidatorNotAdded() public {
        address invalidValidatorAddress = address(1);
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress1, invalidValidatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        bool contains = emailRecoveryModule.workaround_validatorsContains(
            accountAddress1, invalidValidatorAddress
        );

        // Enough guardians have accepted but invalid guardian address
        assertFalse(canStartRecoveryRequest);
        assertTrue(guardianConfig.acceptedWeight >= guardianConfig.threshold);
        assertFalse(contains);
    }

    function test_CanStartRecoveryRequest_ReturnsTrue_WhenThresholdIsHigherThanWeightAndValidatorAdded(
    )
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);

        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress1, validatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        bool contains =
            emailRecoveryModule.workaround_validatorsContains(accountAddress1, validatorAddress);

        // Enough guardians have accepted so that accepted weight is higher than the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(guardianConfig.acceptedWeight > guardianConfig.threshold);
        assertTrue(contains);
    }

    function test_CanStartRecoveryRequest_ReturnsTrue_WhenThresholdIsEqualToWeightAndValidatorAdded(
    )
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress1, validatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        bool contains =
            emailRecoveryModule.workaround_validatorsContains(accountAddress1, validatorAddress);

        // Enough guardians have accepted so that accepted weight is equal to the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(guardianConfig.acceptedWeight == guardianConfig.threshold);
        assertTrue(contains);
    }
}
