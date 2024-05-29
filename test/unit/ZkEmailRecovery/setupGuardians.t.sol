// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";

contract ZkEmailRecovery_setupGuardians_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_SetupGuardians_RevertWhen_SetupAlreadyCalled() public {
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );

        vm.expectRevert(IZkEmailRecovery.SetupAlreadyCalled.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_IncorrectNumberOfWeights() public {
        uint256[] memory invalidGuardianWeights = new uint256[](4);
        invalidGuardianWeights[0] = 1;
        invalidGuardianWeights[1] = 1;
        invalidGuardianWeights[2] = 1;
        invalidGuardianWeights[3] = 1;

        vm.expectRevert(IZkEmailRecovery.IncorrectNumberOfWeights.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            invalidGuardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdIsZero() public {
        uint256 zeroThreshold = 0;

        vm.expectRevert(IZkEmailRecovery.ThresholdCannotBeZero.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            zeroThreshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianAddress() public {
        guardians[2] = address(0);

        vm.expectRevert(IZkEmailRecovery.InvalidGuardianAddress.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_InvalidGuardianWeight() public {
        guardianWeights[1] = 0;

        vm.expectRevert(IZkEmailRecovery.InvalidGuardianWeight.selector);
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );
    }

    function test_SetupGuardians_RevertWhen_ThresholdExceedsTotalWeight()
        public
    {
        uint256 invalidThreshold = totalWeight + 1;

        vm.expectRevert(
            IZkEmailRecovery.ThresholdCannotExceedTotalWeight.selector
        );
        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            invalidThreshold
        );
    }

    function test_SetupGuardians_SetupGuardians_Succeeds() public {
        uint256 expectedGuardianCount = guardians.length;
        uint256 expectedTotalWeight = totalWeight;
        uint256 expectedThreshold = threshold;

        zkEmailRecovery.exposed_setupGuardians(
            accountAddress,
            guardians,
            guardianWeights,
            threshold
        );

        GuardianStorage memory guardianStorage1 = zkEmailRecovery.getGuardian(
            accountAddress,
            guardians[0]
        );
        GuardianStorage memory guardianStorage2 = zkEmailRecovery.getGuardian(
            accountAddress,
            guardians[1]
        );
        GuardianStorage memory guardianStorage3 = zkEmailRecovery.getGuardian(
            accountAddress,
            guardians[2]
        );
        assertEq(
            uint256(guardianStorage1.status),
            uint256(GuardianStatus.REQUESTED)
        );
        assertEq(guardianStorage1.weight, guardianWeights[0]);
        assertEq(
            uint256(guardianStorage2.status),
            uint256(GuardianStatus.REQUESTED)
        );
        assertEq(guardianStorage2.weight, guardianWeights[1]);
        assertEq(
            uint256(guardianStorage3.status),
            uint256(GuardianStatus.REQUESTED)
        );
        assertEq(guardianStorage3.weight, guardianWeights[2]);

        IZkEmailRecovery.GuardianConfig memory guardianConfig = zkEmailRecovery
            .getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
