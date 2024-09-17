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

    function test_AddGuardian_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.addGuardian(guardians[0], guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_SetupNotCalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IGuardianManager.SetupNotCalled.selector);
        emailRecoveryModule.addGuardian(guardians[0], guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianAddress() public {
        address invalidGuardianAddress = address(0);

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.InvalidGuardianAddress.selector, invalidGuardianAddress
            )
        );
        emailRecoveryModule.addGuardian(invalidGuardianAddress, guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_GuardianAddressIsAccountAddress() public {
        address invalidGuardianAddress = accountAddress;

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.InvalidGuardianAddress.selector, invalidGuardianAddress
            )
        );
        emailRecoveryModule.addGuardian(invalidGuardianAddress, guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_AddressAlreadyGuardian() public {
        vm.startPrank(accountAddress);
        vm.expectRevert(IGuardianManager.AddressAlreadyGuardian.selector);
        emailRecoveryModule.addGuardian(guardians[0], guardianWeights[0]);
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianWeight() public {
        address newGuardian = address(1);
        uint256 invalidGuardianWeight = 0;

        vm.startPrank(accountAddress);
        vm.expectRevert(IGuardianManager.InvalidGuardianWeight.selector);
        emailRecoveryModule.addGuardian(newGuardian, invalidGuardianWeight);
    }

    function test_AddGuardian_AddGuardian_Succeeds() public {
        address newGuardian = address(1);
        uint256 newGuardianWeight = 1;

        uint256 expectedGuardianCount = guardians.length + 1;
        uint256 expectedTotalWeight = totalWeight + newGuardianWeight;
        uint256 expectedAcceptedWeight = 0; // no guardians accepted
        uint256 expectedThreshold = threshold; // same threshold

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit IGuardianManager.AddedGuardian(accountAddress, newGuardian, newGuardianWeight);
        emailRecoveryModule.addGuardian(newGuardian, newGuardianWeight);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress, newGuardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage.weight, newGuardianWeight);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.acceptedWeight, expectedAcceptedWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
