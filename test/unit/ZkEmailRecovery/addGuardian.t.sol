// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";

contract ZkEmailRecovery_addGuardian_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_AddGuardian_RevertWhen_AlreadyRecovering() public {
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
        zkEmailRecovery.addGuardian(
            guardians[0],
            guardianWeights[0],
            threshold
        );
    }

    function test_AddGuardian_RevertWhen_SetupNotCalled() public {
        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.SetupNotCalled.selector);
        zkEmailRecovery.addGuardian(
            guardians[0],
            guardianWeights[0],
            threshold
        );
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianAddress() public {
        address invalidGuardianAddress = address(0);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );

        vm.expectRevert(IZkEmailRecovery.InvalidGuardianAddress.selector);
        zkEmailRecovery.addGuardian(
            invalidGuardianAddress,
            guardianWeights[0],
            threshold
        );
    }

    function test_AddGuardian_RevertWhen_AddressAlreadyGuardian() public {
        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );

        vm.expectRevert(IZkEmailRecovery.AddressAlreadyGuardian.selector);
        zkEmailRecovery.addGuardian(
            guardians[0],
            guardianWeights[0],
            threshold
        );
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianWeight() public {
        address newGuardian = address(1);
        uint256 invalidGuardianWeight = 0;

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );

        vm.expectRevert(IZkEmailRecovery.InvalidGuardianWeight.selector);
        zkEmailRecovery.addGuardian(
            newGuardian,
            invalidGuardianWeight,
            threshold
        );
    }

    function test_AddGuardian_AddGuardian_SameThreshold() public {
        address newGuardian = address(1);
        uint256 newGuardianWeight = 1;

        uint256 expectedGuardianCount = guardians.length + 1;
        uint256 expectedTotalWeight = totalWeight + newGuardianWeight;
        uint256 expectedThreshold = threshold; // same threshold

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );

        vm.expectEmit();
        emit IZkEmailRecovery.AddedGuardian(newGuardian);
        zkEmailRecovery.addGuardian(newGuardian, newGuardianWeight, threshold);

        GuardianStorage memory guardianStorage = zkEmailRecovery.getGuardian(
            accountAddress,
            newGuardian
        );
        assertEq(
            uint256(guardianStorage.status),
            uint256(GuardianStatus.REQUESTED)
        );
        assertEq(guardianStorage.weight, newGuardianWeight);

        IZkEmailRecovery.GuardianConfig memory guardianConfig = zkEmailRecovery
            .getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }

    function test_AddGuardian_AddGuardian_DifferentThreshold() public {
        address newGuardian = address(1);
        uint256 newGuardianWeight = 1;
        uint256 newThreshold = 3;

        uint256 expectedGuardianCount = guardians.length + 1;
        uint256 expectedTotalWeight = totalWeight + newGuardianWeight;
        uint256 expectedThreshold = newThreshold; // new threshold

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );

        zkEmailRecovery.addGuardian(
            newGuardian,
            newGuardianWeight,
            newThreshold
        );

        IZkEmailRecovery.GuardianConfig memory guardianConfig = zkEmailRecovery
            .getGuardianConfig(accountAddress);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
