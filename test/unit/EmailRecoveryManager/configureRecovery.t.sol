// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

error SetupAlreadyCalled();

contract ZkEmailRecovery_configureRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_ConfigureRecovery_RevertWhen_AlreadyRecovering() public {
    //     acceptGuardian(accountSalt1);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     vm.expectRevert(SetupAlreadyCalled.selector);
    //     vm.startPrank(accountAddress);
    //     emailRecoveryManager.configureRecovery(guardians, guardianWeights, threshold, delay,
    // expiry);
    //     vm.stopPrank();
    // }

    // // Integration test?
    // function test_ConfigureRecovery_RevertWhen_ConfigureRecoveryCalledTwice() public {
    //     vm.startPrank(accountAddress);

    //     vm.expectRevert(SetupAlreadyCalled.selector);
    //     emailRecoveryManager.configureRecovery(guardians, guardianWeights, threshold, delay,
    // expiry);
    //     vm.stopPrank();
    // }

    // function test_ConfigureRecovery_Succeeds() public {
    //     vm.prank(accountAddress);
    //     instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
    //     vm.stopPrank();

    //     // Install recovery module - configureRecovery is called on `onInstall`
    //     vm.prank(accountAddress);
    //     vm.expectEmit();
    //     emit IEmailRecoveryManager.RecoveryConfigured(accountAddress, guardians.length);
    //     instance.installModule({
    //         moduleTypeId: MODULE_TYPE_EXECUTOR,
    //         module: recoveryModuleAddress,
    //         data: abi.encode(
    //             address(validator),
    //             guardians,
    //             guardianWeights,
    //             threshold,
    //             delay,
    //             expiry,
    //             acceptanceSubjectTemplates(),
    //             recoverySubjectTemplates()
    //         )
    //     });
    //     vm.stopPrank();

    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         emailRecoveryManager.getRecoveryConfig(accountAddress);
    //     assertEq(recoveryConfig.delay, delay);
    //     assertEq(recoveryConfig.expiry, expiry);

    //     IEmailRecoveryManager.GuardianConfig memory guardianConfig =
    //         emailRecoveryManager.getGuardianConfig(accountAddress);
    //     assertEq(guardianConfig.guardianCount, guardians.length);
    //     assertEq(guardianConfig.threshold, threshold);

    //     GuardianStorage memory guardian =
    //         emailRecoveryManager.getGuardian(accountAddress, guardians[0]);
    //     assertEq(uint256(guardian.status), uint256(GuardianStatus.REQUESTED));
    //     assertEq(guardian.weight, guardianWeights[0]);
    // }
}
