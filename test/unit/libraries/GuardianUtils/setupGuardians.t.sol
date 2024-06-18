// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";

contract GuardianUtils_setupGuardians_Test is UnitBase {
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

        vm.expectRevert(GuardianUtils.IncorrectNumberOfWeights.selector);
        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, invalidGuardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdIsZero() public {
        uint256 zeroThreshold = 0;

        vm.expectRevert(GuardianUtils.ThresholdCannotBeZero.selector);
        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, guardianWeights, zeroThreshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianAddress() public {
        guardians[0] = address(0);

        vm.expectRevert(GuardianUtils.InvalidGuardianAddress.selector);
        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_GuardianAddressIsAccountAddress() public {
        guardians[0] = accountAddress;

        vm.expectRevert(GuardianUtils.InvalidGuardianAddress.selector);
        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianWeight() public {
        guardianWeights[0] = 0;

        vm.expectRevert(GuardianUtils.InvalidGuardianWeight.selector);
        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_AddressAlreadyGuardian() public {
        guardians[0] = guardians[1];

        vm.expectRevert(GuardianUtils.AddressAlreadyGuardian.selector);
        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, guardianWeights, threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdExceedsTotalWeight() public {
        uint256 invalidThreshold = totalWeight + 1;

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(GuardianUtils.ThresholdCannotExceedTotalWeight.selector);
        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, guardianWeights, invalidThreshold
        );
    }

    function test_SetupGuardians_Succeeds() public {
        uint256 expectedGuardianCount = guardians.length;
        uint256 expectedTotalWeight = totalWeight;
        uint256 expectedThreshold = threshold;

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        emailRecoveryManager.exposed_setupGuardians(
            accountAddress, guardians, guardianWeights, threshold
        );

        GuardianStorage memory guardianStorage1 =
            emailRecoveryManager.getGuardian(accountAddress, guardians[0]);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryManager.getGuardian(accountAddress, guardians[1]);
        GuardianStorage memory guardianStorage3 =
            emailRecoveryManager.getGuardian(accountAddress, guardians[2]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage1.weight, guardianWeights[0]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage2.weight, guardianWeights[1]);
        assertEq(uint256(guardianStorage3.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage3.weight, guardianWeights[2]);

        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
