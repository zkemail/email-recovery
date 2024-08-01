// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract UniversalEmailRecoveryModule_canStartRecoveryRequest_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenThresholdCannotBeMet() public {
        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress, validatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress);
        bool contains =
            emailRecoveryModule.workaround_validatorsContains(accountAddress, validatorAddress);

        // No guardians have accepted
        assertFalse(canStartRecoveryRequest);
        assertFalse(guardianConfig.acceptedWeight >= guardianConfig.threshold);
        assertTrue(contains);
    }

    function test_CanStartRecoveryRequest_ReturnsFalse_WhenValidatorNotAdded() public {
        address invalidValidatorAddress = address(1);
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);

        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress, invalidValidatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress);
        bool contains = emailRecoveryModule.workaround_validatorsContains(
            accountAddress, invalidValidatorAddress
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
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        acceptGuardian(accountSalt3);

        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress, validatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress);
        bool contains =
            emailRecoveryModule.workaround_validatorsContains(accountAddress, validatorAddress);

        // Enough guardians have accepted so that accepted weight is higher than the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(guardianConfig.acceptedWeight > guardianConfig.threshold);
        assertTrue(contains);
    }

    function test_CanStartRecoveryRequest_ReturnsTrue_WhenThresholdIsEqualToWeightAndValidatorAdded(
    )
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);

        bool canStartRecoveryRequest =
            emailRecoveryModule.canStartRecoveryRequest(accountAddress, validatorAddress);

        // Checking accepted weight and sentinel list storage are what we expect for this test case
        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress);
        bool contains =
            emailRecoveryModule.workaround_validatorsContains(accountAddress, validatorAddress);

        // Enough guardians have accepted so that accepted weight is equal to the threshold
        assertTrue(canStartRecoveryRequest);
        assertTrue(guardianConfig.acceptedWeight == guardianConfig.threshold);
        assertTrue(contains);
    }
}
