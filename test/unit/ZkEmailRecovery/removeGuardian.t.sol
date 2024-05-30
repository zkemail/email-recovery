// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";

contract ZkEmailRecovery_removeGuardian_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_RemoveGuardian_RevertWhen_UnauthorizedAccountForGuardian()
        public
    {
        address guardian = guardian1;

        vm.expectRevert(
            IZkEmailRecovery.UnauthorizedAccountForGuardian.selector
        );
        zkEmailRecovery.removeGuardian(guardian, threshold);
    }

    function test_RemoveGuardian_RevertWhen_AlreadyRecovering() public {
        address guardian = guardian1;

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.removeGuardian(guardian, threshold);
    }

    function test_RemoveGuardian_RevertWhen_ThresholdExceedsTotalWeight()
        public
    {
        address guardian = guardian2; // guardian 2 weight is 2
        // threshold = 3
        // totalWeight = 4
        // weight = 2

        // Fails if totalWeight - weight < threshold
        // (totalWeight - weight == 4 - 2) = 2
        // (weight < threshold == 2 < 3) = fails

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(
            IZkEmailRecovery.ThresholdCannotExceedTotalWeight.selector
        );
        zkEmailRecovery.removeGuardian(guardian, threshold);
    }

    function test_RemoveGuardian_SucceedsWithSameThreshold() public {
        address guardian = guardian1; // guardian 1 weight is 1
        // threshold = 3
        // totalWeight = 4
        // weight = 1

        // Fails if totalWeight - weight < threshold
        // (totalWeight - weight == 4 - 1) = 3
        // (weight < threshold == 3 < 3) = succeeds

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);

        vm.startPrank(accountAddress);
        zkEmailRecovery.removeGuardian(guardian, threshold);

        GuardianStorage memory guardianStorage = zkEmailRecovery.getGuardian(
            accountAddress,
            guardian
        );
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage.weight, 0);

        IZkEmailRecovery.GuardianConfig memory guardianConfig = zkEmailRecovery
            .getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length - 1);
        assertEq(guardianConfig.totalWeight, totalWeight - guardianWeights[0]);
        assertEq(guardianConfig.threshold, threshold);
    }

    function test_RemoveGuardian_SucceedsWithDifferentThreshold() public {
        address guardian = guardian1;
        uint256 newThreshold = threshold - 1;

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);

        vm.startPrank(accountAddress);
        zkEmailRecovery.removeGuardian(guardian, newThreshold);

        IZkEmailRecovery.GuardianConfig memory guardianConfig = zkEmailRecovery
            .getGuardianConfig(accountAddress);
        assertEq(guardianConfig.threshold, newThreshold);
    }
}
