// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_addGuardian_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    EmailRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule = new EmailRecoveryModule{ salt: "test salt" }(address(emailRecoveryManager));
        recoveryModuleAddress = address(recoveryModule);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, recoveryModuleAddress)
        });
        // Install recovery module - configureRecovery is called on `onInstall`
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(address(validator), guardians, guardianWeights, threshold, delay, expiry)
        });
    }

    function test_AddGuardian_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        emailRecoveryManager.addGuardian(guardians[0], guardianWeights[0], threshold);
    }

    function test_AddGuardian_RevertWhen_SetupNotCalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.SetupNotCalled.selector);
        emailRecoveryManager.addGuardian(guardians[0], guardianWeights[0], threshold);
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianAddress() public {
        address invalidGuardianAddress = address(0);

        vm.startPrank(accountAddress);

        vm.expectRevert(IEmailRecoveryManager.InvalidGuardianAddress.selector);
        emailRecoveryManager.addGuardian(invalidGuardianAddress, guardianWeights[0], threshold);
    }

    function test_AddGuardian_RevertWhen_GuardianAddressIsAccountAddress() public {
        address invalidGuardianAddress = accountAddress;

        vm.startPrank(accountAddress);

        vm.expectRevert(IEmailRecoveryManager.InvalidGuardianAddress.selector);
        emailRecoveryManager.addGuardian(invalidGuardianAddress, guardianWeights[0], threshold);
    }

    function test_AddGuardian_RevertWhen_AddressAlreadyGuardian() public {
        vm.startPrank(accountAddress);

        vm.expectRevert(IEmailRecoveryManager.AddressAlreadyGuardian.selector);
        emailRecoveryManager.addGuardian(guardians[0], guardianWeights[0], threshold);
    }

    function test_AddGuardian_RevertWhen_InvalidGuardianWeight() public {
        address newGuardian = address(1);
        uint256 invalidGuardianWeight = 0;

        vm.startPrank(accountAddress);

        vm.expectRevert(IEmailRecoveryManager.InvalidGuardianWeight.selector);
        emailRecoveryManager.addGuardian(newGuardian, invalidGuardianWeight, threshold);
    }

    function test_AddGuardian_AddGuardian_SameThreshold() public {
        address newGuardian = address(1);
        uint256 newGuardianWeight = 1;

        uint256 expectedGuardianCount = guardians.length + 1;
        uint256 expectedTotalWeight = totalWeight + newGuardianWeight;
        uint256 expectedThreshold = threshold; // same threshold

        vm.startPrank(accountAddress);

        vm.expectEmit();
        emit IEmailRecoveryManager.AddedGuardian(accountAddress, newGuardian);
        emailRecoveryManager.addGuardian(newGuardian, newGuardianWeight, threshold);

        GuardianStorage memory guardianStorage =
            emailRecoveryManager.getGuardian(accountAddress, newGuardian);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardianStorage.weight, newGuardianWeight);

        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, expectedGuardianCount);
        assertEq(guardianConfig.totalWeight, expectedTotalWeight);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }

    function test_AddGuardian_AddGuardian_DifferentThreshold() public {
        address newGuardian = address(1);
        uint256 newGuardianWeight = 1;
        uint256 newThreshold = 3;

        uint256 expectedThreshold = newThreshold; // new threshold

        vm.startPrank(accountAddress);

        emailRecoveryManager.addGuardian(newGuardian, newGuardianWeight, newThreshold);

        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.threshold, expectedThreshold);
    }
}
