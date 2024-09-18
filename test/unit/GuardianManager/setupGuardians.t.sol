// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract GuardianManager_setupGuardians_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_SetupGuardians_RevertWhen_IncorrectNumberOfWeights() public {
        uint256[] memory invalidGuardianWeights = new uint256[](4);
        invalidGuardianWeights[0] = 1;
        invalidGuardianWeights[1] = 1;
        invalidGuardianWeights[2] = 1;
        invalidGuardianWeights[3] = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.IncorrectNumberOfWeights.selector,
                guardians1.length,
                invalidGuardianWeights.length
            )
        );
        emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, invalidGuardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdIsZero() public {
        uint256 zeroThreshold = 0;

        vm.expectRevert(IGuardianManager.ThresholdCannotBeZero.selector);
        emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, guardianWeights, zeroThreshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianAddress() public {
        guardians1[0] = address(0);

        vm.expectRevert(
            abi.encodeWithSelector(IGuardianManager.InvalidGuardianAddress.selector, guardians1[0])
        );
        emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_GuardianAddressIsAccountAddress() public {
        guardians1[0] = accountAddress1;

        vm.expectRevert(
            abi.encodeWithSelector(IGuardianManager.InvalidGuardianAddress.selector, guardians1[0])
        );
        emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianWeight() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        guardianWeights[0] = 0;

        vm.expectRevert(IGuardianManager.InvalidGuardianWeight.selector);
        emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_AddressAlreadyGuardian() public {
        guardians1[0] = guardians1[1];

        vm.expectRevert(IGuardianManager.AddressAlreadyGuardian.selector);
        emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdExceedsTotalWeight() public {
        uint256 invalidThreshold = totalWeight + 1;

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.ThresholdExceedsTotalWeight.selector, invalidThreshold, totalWeight
            )
        );
        emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, guardianWeights, invalidThreshold
        );
    }

    function test_SetupGuardians_Succeeds() public {
        uint256 expectedGuardianCount = guardians1.length;
        uint256 expectedTotalWeight = totalWeight;
        uint256 expectedAcceptedWeight = 0; // no guardians accepted
        uint256 expectedThreshold = threshold;

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        (uint256 guardianCount, uint256 totalWeight) = emailRecoveryModule.exposed_setupGuardians(
            accountAddress1, guardians1, guardianWeights, threshold
        );

        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        GuardianStorage memory guardianStorage3 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[2]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage1.weight, guardianWeights[0]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage2.weight, guardianWeights[1]);
        assertEq(uint256(guardianStorage3.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage3.weight, guardianWeights[2]);

        assertEq(guardianCount, expectedGuardianCount);
        assertEq(totalWeight, expectedTotalWeight);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.acceptedWeight, expectedAcceptedWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
