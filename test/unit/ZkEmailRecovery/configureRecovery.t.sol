// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_configureRecovery_Test is UnitBase {
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

    function test_ConfigureRecovery_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.expectRevert(IZkEmailRecovery.SetupAlreadyCalled.selector);
        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();
    }

    // Integration test?
    function test_ConfigureRecovery_RevertWhen_ConfigureRecoveryCalledTwice() public {
        vm.startPrank(accountAddress);

        vm.expectRevert(IZkEmailRecovery.SetupAlreadyCalled.selector);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();
    }

    function test_ConfigureRecovery_Succeeds() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        address expectedRouterAddress =
            zkEmailRecovery.computeRouterAddress(keccak256(abi.encode(accountAddress)));

        // Install recovery module - configureRecovery is called on `onInstall`
        vm.prank(accountAddress);
        vm.expectEmit();
        emit IZkEmailRecovery.RecoveryConfigured(
            accountAddress, recoveryModuleAddress, guardians.length, expectedRouterAddress
        );
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(address(validator), guardians, guardianWeights, threshold, delay, expiry)
        });
        vm.stopPrank();

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            zkEmailRecovery.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.recoveryModule, recoveryModuleAddress);
        assertEq(recoveryConfig.delay, delay);
        assertEq(recoveryConfig.expiry, expiry);

        IZkEmailRecovery.GuardianConfig memory guardianConfig =
            zkEmailRecovery.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, guardians.length);
        assertEq(guardianConfig.threshold, threshold);

        GuardianStorage memory guardian = zkEmailRecovery.getGuardian(accountAddress, guardians[0]);
        assertEq(uint256(guardian.status), uint256(GuardianStatus.REQUESTED));
        assertEq(guardian.weight, guardianWeights[0]);

        address accountForRouter = zkEmailRecovery.getAccountForRouter(expectedRouterAddress);
        assertEq(accountForRouter, accountAddress);

        address routerForAccount = zkEmailRecovery.getRouterForAccount(accountAddress);
        assertEq(routerForAccount, expectedRouterAddress);
    }
}
