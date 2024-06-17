// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";

contract ZkEmailRecovery_configureRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function setUp() public override {
        super.setUp();
    }

    function test_ConfigureRecovery_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        vm.expectRevert(IEmailRecoveryManager.SetupAlreadyCalled.selector);
        vm.startPrank(accountAddress);
        emailRecoveryManager.configureRecovery(guardians, guardianWeights, threshold, delay, expiry);
    }

    function test_ConfigureRecovery_RevertWhen_ConfigureRecoveryCalledTwice() public {
        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.SetupAlreadyCalled.selector);
        emailRecoveryManager.configureRecovery(guardians, guardianWeights, threshold, delay, expiry);
    }

    function test_ConfigureRecovery_RevertWhen_RecoveryModuleNotInstalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.prank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.configureRecovery(guardians, guardianWeights, threshold, delay, expiry);
    }

    function test_ConfigureRecovery_Succeeds() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        // Install recovery module - configureRecovery is called on `onInstall`
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryConfigured(accountAddress, guardians.length);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                address(validator),
                functionSelector,
                guardians,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });

        IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
            emailRecoveryManager.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.delay, delay);
        assertEq(recoveryConfig.expiry, expiry);

        IEmailRecoveryManager.GuardianConfig memory guardianConfig =
            emailRecoveryManager.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length);
        assertEq(guardianConfig.totalWeight, totalWeight);
        assertEq(guardianConfig.threshold, threshold);

        GuardianStorage memory guardian =
            emailRecoveryManager.getGuardian(accountAddress, guardians[0]);
        assertEq(uint256(guardian.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardian.weight, guardianWeights[0]);
    }
}
