// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_configureRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_ConfigureRecovery_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);

        vm.expectRevert(IEmailRecoveryManager.SetupAlreadyCalled.selector);
        vm.startPrank(accountAddress1);
        emailRecoveryModule.exposed_configureRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
    }

    function test_ConfigureRecovery_RevertWhen_ConfigureRecoveryCalledTwice() public {
        vm.startPrank(accountAddress1);
        vm.expectRevert(IEmailRecoveryManager.SetupAlreadyCalled.selector);
        emailRecoveryModule.exposed_configureRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
    }

    function test_ConfigureRecovery_Succeeds() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.startPrank(accountAddress1);
        emailRecoveryModule.workaround_validatorsPush(accountAddress1, validatorAddress);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertFalse(isActivated);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigured(
            instance1.account, guardians1.length, totalWeight, threshold
        );
        emailRecoveryModule.exposed_configureRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            emailRecoveryModule.getRecoveryConfig(accountAddress1);
        assertEq(recoveryConfig.delay, delay);
        assertEq(recoveryConfig.expiry, expiry);

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.guardianCount, guardians1.length);
        assertEq(guardianConfig.totalWeight, totalWeight);
        assertEq(guardianConfig.acceptedWeight, 0); // no guardians1 accepted yet
        assertEq(guardianConfig.threshold, threshold);

        GuardianStorage memory guardian =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardian.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardian.weight, guardianWeights[0]);

        isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertTrue(isActivated);
    }

    function test_ConfigureRecovery_RevertWhen_ZeroGuardians() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.startPrank(accountAddress1);
        emailRecoveryModule.workaround_validatorsPush(accountAddress1, validatorAddress);
        address[] memory zeroGuardians;

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.IncorrectNumberOfWeights.selector,
                zeroGuardians.length,
                guardianWeights.length
            )
        );
        emailRecoveryModule.exposed_configureRecovery(
            zeroGuardians, guardianWeights, threshold, delay, expiry
        );
    }

    function test_ConfigureRecovery_RevertWhen_ZeroGuardianWeights() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.startPrank(accountAddress1);
        emailRecoveryModule.workaround_validatorsPush(accountAddress1, validatorAddress);
        uint256[] memory zeroGuardianWeights;

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.IncorrectNumberOfWeights.selector,
                guardians1.length,
                zeroGuardianWeights.length
            )
        );
        emailRecoveryModule.exposed_configureRecovery(
            guardians1, zeroGuardianWeights, threshold, delay, expiry
        );
    }

    function test_ConfigureRecovery_RevertWhen_ZeroThreshold() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.startPrank(accountAddress1);
        emailRecoveryModule.workaround_validatorsPush(accountAddress1, validatorAddress);
        uint256 zeroThreshold = 0;

        vm.expectRevert(IGuardianManager.ThresholdCannotBeZero.selector);
        emailRecoveryModule.exposed_configureRecovery(
            guardians1, guardianWeights, zeroThreshold, delay, expiry
        );
    }

    function test_ConfigureRecovery_RevertWhen_NoGuardians() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.startPrank(accountAddress1);
        emailRecoveryModule.workaround_validatorsPush(accountAddress1, validatorAddress);

        address[] memory zeroGuardians;
        uint256[] memory zeroGuardianWeights;

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.ThresholdExceedsTotalWeight.selector, threshold, 0
            )
        );
        emailRecoveryModule.exposed_configureRecovery(
            zeroGuardians, zeroGuardianWeights, threshold, delay, expiry
        );
    }
}
