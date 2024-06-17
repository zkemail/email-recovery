// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

error ThresholdCannotExceedTotalWeight();
error UnauthorizedAccountForGuardian();

contract ZkEmailRecovery_removeGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_RemoveGuardian_RevertWhen_UnauthorizedAccountForGuardian() public {
    //     address guardian = guardian1;

    //     vm.expectRevert(UnauthorizedAccountForGuardian.selector);
    //     emailRecoveryManager.removeGuardian(guardian, threshold);
    // }

    // function test_RemoveGuardian_RevertWhen_AlreadyRecovering() public {
    //     address guardian = guardian1;

    //     acceptGuardian(accountSalt1);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
    //     emailRecoveryManager.removeGuardian(guardian, threshold);
    // }

    // function test_RemoveGuardian_RevertWhen_ThresholdExceedsTotalWeight() public {
    //     address guardian = guardian2; // guardian 2 weight is 2
    //     // threshold = 3
    //     // totalWeight = 4
    //     // weight = 2

    //     // Fails if totalWeight - weight < threshold
    //     // (totalWeight - weight == 4 - 2) = 2
    //     // (weight < threshold == 2 < 3) = fails

    //     acceptGuardian(accountSalt1);

    //     vm.startPrank(accountAddress);
    //     vm.expectRevert(ThresholdCannotExceedTotalWeight.selector);
    //     emailRecoveryManager.removeGuardian(guardian, threshold);
    // }

    // function test_RemoveGuardian_SucceedsWithSameThreshold() public {
    //     address guardian = guardian1; // guardian 1 weight is 1
    //     // threshold = 3
    //     // totalWeight = 4
    //     // weight = 1

    //     // Fails if totalWeight - weight < threshold
    //     // (totalWeight - weight == 4 - 1) = 3
    //     // (weight < threshold == 3 < 3) = succeeds

    //     acceptGuardian(accountSalt1);

    //     vm.startPrank(accountAddress);
    //     emailRecoveryManager.removeGuardian(guardian, threshold);

    //     GuardianStorage memory guardianStorage =
    //         emailRecoveryManager.getGuardian(accountAddress, guardian);
    //     assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.NONE));
    //     assertEq(guardianStorage.weight, 0);

    //     IEmailRecoveryManager.GuardianConfig memory guardianConfig =
    //         emailRecoveryManager.getGuardianConfig(accountAddress);
    //     assertEq(guardianConfig.guardianCount, guardians.length - 1);
    //     assertEq(guardianConfig.totalWeight, totalWeight - guardianWeights[0]);
    //     assertEq(guardianConfig.threshold, threshold);
    // }

    // function test_RemoveGuardian_SucceedsWithDifferentThreshold() public {
    //     address guardian = guardian1;
    //     uint256 newThreshold = threshold - 1;

    //     acceptGuardian(accountSalt1);

    //     vm.startPrank(accountAddress);
    //     emailRecoveryManager.removeGuardian(guardian, newThreshold);

    //     IEmailRecoveryManager.GuardianConfig memory guardianConfig =
    //         emailRecoveryManager.getGuardianConfig(accountAddress);
    //     assertEq(guardianConfig.threshold, newThreshold);
    // }
}
