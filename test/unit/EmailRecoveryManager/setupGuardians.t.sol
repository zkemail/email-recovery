// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract EmailRecoveryManager_setupGuardians_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_SetupGuardians_Succeeds() public {
        uint256 expectedGuardianCount = guardians.length;
        uint256 expectedTotalWeight = totalWeight;
        uint256 expectedThreshold = threshold;

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        (uint256 guardianCount, uint256 totalWeight) = emailRecoveryManager.exposed_setupGuardians(
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

        assertEq(guardianCount, expectedGuardianCount);
        assertEq(totalWeight, expectedTotalWeight);

        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.acceptedWeight, 0); // no guardians accepted
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
