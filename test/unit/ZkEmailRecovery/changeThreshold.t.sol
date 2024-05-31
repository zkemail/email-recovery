// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_changeThreshold_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
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

    function test_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.changeThreshold(threshold);
    }

    function test_RevertWhen_SetupNotCalled() public {
        vm.expectRevert(IZkEmailRecovery.SetupNotCalled.selector);
        zkEmailRecovery.changeThreshold(threshold);
    }

    function test_RevertWhen_ThresholdExceedsTotalWeight() public {
        uint256 highThreshold = totalWeight + 1;

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.ThresholdCannotExceedTotalWeight.selector);
        zkEmailRecovery.changeThreshold(highThreshold);
    }

    function test_RevertWhen_ThresholdIsZero() public {
        uint256 zeroThreshold = 0;

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.ThresholdCannotBeZero.selector);
        zkEmailRecovery.changeThreshold(zeroThreshold);
    }

    function test_ChangeThreshold_IncreaseThreshold() public {
        uint256 newThreshold = threshold + 1;

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit IZkEmailRecovery.ChangedThreshold(accountAddress, newThreshold);
        zkEmailRecovery.changeThreshold(newThreshold);

        IZkEmailRecovery.GuardianConfig memory guardianConfig =
            zkEmailRecovery.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length);
        assertEq(guardianConfig.threshold, newThreshold);
    }

    function test_ChangeThreshold_DecreaseThreshold() public {
        uint256 newThreshold = threshold - 1;

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit IZkEmailRecovery.ChangedThreshold(accountAddress, newThreshold);
        zkEmailRecovery.changeThreshold(newThreshold);

        IZkEmailRecovery.GuardianConfig memory guardianConfig =
            zkEmailRecovery.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length);
        assertEq(guardianConfig.threshold, newThreshold);
    }
}
