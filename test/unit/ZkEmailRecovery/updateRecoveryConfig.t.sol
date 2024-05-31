// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_updateRecoveryConfig_Test is UnitBase {
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

    function test_UpdateRecoveryConfig_RevertWhen_AlreadyRecovering() public {
        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(recoveryModuleAddress, delay, expiry);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_AccountNotConfigured() public {
        address nonConfiguredAccount = address(0);
        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(recoveryModuleAddress, delay, expiry);

        vm.startPrank(nonConfiguredAccount);
        vm.expectRevert(IZkEmailRecovery.AccountNotConfigured.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_InvalidRecoveryModule() public {
        address invalidRecoveryModule = address(0);

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(invalidRecoveryModule, delay, expiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.InvalidRecoveryModule.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_DelayMoreThanExpiry() public {
        uint256 invalidDelay = expiry + 1 seconds;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(recoveryModuleAddress, invalidDelay, expiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.DelayMoreThanExpiry.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShort() public {
        uint256 newDelay = 1 days;
        uint256 newExpiry = 2 days;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(recoveryModuleAddress, newDelay, newExpiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryWindowTooShort.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShortByOneSecond() public {
        uint256 newDelay = 1 seconds;
        uint256 newExpiry = 2 days;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(recoveryModuleAddress, newDelay, newExpiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryWindowTooShort.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_SucceedsWhenRecoveryWindowEqualsMinimumRecoveryWindow()
        public
    {
        uint256 newDelay = 0 seconds;
        uint256 newExpiry = 2 days;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(recoveryModuleAddress, newDelay, newExpiry);

        vm.startPrank(accountAddress);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = zkEmailRecovery.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.recoveryModule, recoveryModuleAddress);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }

    function test_UpdateRecoveryConfig_Succeeds() public {
        address newRecoveryModule = recoveryModuleAddress;
        uint256 newDelay = 1 days;
        uint256 newExpiry = 4 weeks;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            IZkEmailRecovery.RecoveryConfig(newRecoveryModule, newDelay, newExpiry);

        vm.startPrank(accountAddress);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = zkEmailRecovery.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.recoveryModule, newRecoveryModule);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }
}
