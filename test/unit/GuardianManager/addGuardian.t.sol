// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract GuardianManager_addGuardian_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_AddGuardian_RevertWhen_KillSwitchEnabled() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.KillSwitchEnabled.selector);
        emailRecoveryModule.addGuardian(guardians1[0], guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.addGuardian(guardians1[0], guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_SetupNotCalled() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.SetupNotCalled.selector);
        emailRecoveryModule.addGuardian(guardians1[0], guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianAddress() public {
        address invalidGuardianAddress = address(0);

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.InvalidGuardianAddress.selector, invalidGuardianAddress
            )
        );
        emailRecoveryModule.addGuardian(invalidGuardianAddress, guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_GuardianAddressIsAccountAddress() public {
        address invalidGuardianAddress = accountAddress1;

        vm.startPrank(accountAddress1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.InvalidGuardianAddress.selector, invalidGuardianAddress
            )
        );
        emailRecoveryModule.addGuardian(invalidGuardianAddress, guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_AddressAlreadyGuardian() public {
        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.AddressAlreadyGuardian.selector);
        emailRecoveryModule.addGuardian(guardians1[0], guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianWeight() public {
        address newGuardian = address(1);
        uint256 invalidGuardianWeight = 0;

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.InvalidGuardianWeight.selector);
        emailRecoveryModule.addGuardian(newGuardian, invalidGuardianWeight);
    }

    function test_AddGuardian_AddGuardian_Succeeds() public {
        address newGuardian = address(1);
        uint256 newGuardianWeight = 1;

        uint256 expectedGuardianCount = guardians1.length + 1;
        uint256 expectedTotalWeight = totalWeight + newGuardianWeight;
        uint256 expectedAcceptedWeight = 0; // no guardians1 accepted
        uint256 expectedThreshold = threshold; // same threshold

        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit IGuardianManager.AddedGuardian(accountAddress1, newGuardian, newGuardianWeight);
        emailRecoveryModule.addGuardian(newGuardian, newGuardianWeight);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress1, newGuardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage.weight, newGuardianWeight);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.acceptedWeight, expectedAcceptedWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
