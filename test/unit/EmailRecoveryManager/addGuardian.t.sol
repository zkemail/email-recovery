// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

error SetupNotCalled();
error InvalidGuardianAddress();
error AddressAlreadyGuardian();
error InvalidGuardianWeight();

event AddedGuardian(address indexed account, address indexed guardian);

contract ZkEmailRecovery_addGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_AddGuardian_RevertWhen_AlreadyRecovering() public {
    //     acceptGuardian(accountSalt1);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
    //     emailRecoveryManager.addGuardian(guardians[0], guardianWeights[0], threshold);
    // }

    // function test_AddGuardian_RevertWhen_SetupNotCalled() public {
    //     vm.prank(accountAddress);
    //     instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
    //     vm.stopPrank();

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(SetupNotCalled.selector);
    //     emailRecoveryManager.addGuardian(guardians[0], guardianWeights[0], threshold);
    // }

    // function test_AddGuardian_RevertWhen_InvalidGuardianAddress() public {
    //     address invalidGuardianAddress = address(0);

    //     vm.startPrank(accountAddress);

    //     vm.expectRevert(InvalidGuardianAddress.selector);
    //     emailRecoveryManager.addGuardian(invalidGuardianAddress, guardianWeights[0], threshold);
    // }

    // function test_AddGuardian_RevertWhen_GuardianAddressIsAccountAddress() public {
    //     address invalidGuardianAddress = accountAddress;

    //     vm.startPrank(accountAddress);

    //     vm.expectRevert(InvalidGuardianAddress.selector);
    //     emailRecoveryManager.addGuardian(invalidGuardianAddress, guardianWeights[0], threshold);
    // }

    // function test_AddGuardian_RevertWhen_AddressAlreadyGuardian() public {
    //     vm.startPrank(accountAddress);

    //     vm.expectRevert(AddressAlreadyGuardian.selector);
    //     emailRecoveryManager.addGuardian(guardians[0], guardianWeights[0], threshold);
    // }

    // function test_AddGuardian_RevertWhen_InvalidGuardianWeight() public {
    //     address newGuardian = address(1);
    //     uint256 invalidGuardianWeight = 0;

    //     vm.startPrank(accountAddress);

    //     vm.expectRevert(InvalidGuardianWeight.selector);
    //     emailRecoveryManager.addGuardian(newGuardian, invalidGuardianWeight, threshold);
    // }

    // function test_AddGuardian_AddGuardian_SameThreshold() public {
    //     address newGuardian = address(1);
    //     uint256 newGuardianWeight = 1;

    //     uint256 expectedGuardianCount = guardians.length + 1;
    //     uint256 expectedTotalWeight = totalWeight + newGuardianWeight;
    //     uint256 expectedThreshold = threshold; // same threshold

    //     vm.startPrank(accountAddress);

    //     vm.expectEmit();
    //     emit AddedGuardian(accountAddress, newGuardian);
    //     emailRecoveryManager.addGuardian(newGuardian, newGuardianWeight, threshold);

    //     GuardianStorage memory guardianStorage =
    //         emailRecoveryManager.getGuardian(accountAddress, newGuardian);
    //     assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.REQUESTED));
    //     assertEq(guardianStorage.weight, newGuardianWeight);

    //     IEmailRecoveryManager.GuardianConfig memory guardianConfig =
    //         emailRecoveryManager.getGuardianConfig(accountAddress);
    //     assertEq(guardianConfig.guardianCount, expectedGuardianCount);
    //     assertEq(guardianConfig.totalWeight, expectedTotalWeight);
    //     assertEq(guardianConfig.threshold, expectedThreshold);
    // }

    // function test_AddGuardian_AddGuardian_DifferentThreshold() public {
    //     address newGuardian = address(1);
    //     uint256 newGuardianWeight = 1;
    //     uint256 newThreshold = 3;

    //     uint256 expectedThreshold = newThreshold; // new threshold

    //     vm.startPrank(accountAddress);

    //     emailRecoveryManager.addGuardian(newGuardian, newGuardianWeight, newThreshold);

    //     IEmailRecoveryManager.GuardianConfig memory guardianConfig =
    //         emailRecoveryManager.getGuardianConfig(accountAddress);
    //     assertEq(guardianConfig.threshold, expectedThreshold);
    // }
}
