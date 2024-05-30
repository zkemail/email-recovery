// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";

contract ZkEmailRecovery_updateRecoveryConfig_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_UpdateRecoveryConfig_RevertWhen_AlreadyRecovering() public {
        IZkEmailRecovery.RecoveryConfig memory recoveryConfig = IZkEmailRecovery
            .RecoveryConfig(recoveryModuleAddress, delay, expiry);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_AccountNotConfigured()
        public
    {
        IZkEmailRecovery.RecoveryConfig memory recoveryConfig = IZkEmailRecovery
            .RecoveryConfig(recoveryModuleAddress, delay, expiry);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.AccountNotConfigured.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_InvalidRecoveryModule()
        public
    {
        address invalidRecoveryModule = address(0);

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig = IZkEmailRecovery
            .RecoveryConfig(invalidRecoveryModule, delay, expiry);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.InvalidRecoveryModule.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_DelayMoreThanExpiry() public {
        uint256 invalidDelay = expiry + 1 seconds;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig = IZkEmailRecovery
            .RecoveryConfig(recoveryModuleAddress, invalidDelay, expiry);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.DelayMoreThanExpiry.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_RevertWhen_RecoveryWindowTooShort()
        public
    {
        uint256 newDelay = 1 hours;
        uint256 newExpiry = 24 hours;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig = IZkEmailRecovery
            .RecoveryConfig(recoveryModuleAddress, newDelay, newExpiry);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryWindowTooShort.selector);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);
    }

    function test_UpdateRecoveryConfig_UpdateRecoveryConfig_Succeeds() public {
        address newRecoveryModule = address(1);
        uint256 newDelay = 1 days;
        uint256 newExpiry = 4 weeks;

        IZkEmailRecovery.RecoveryConfig memory recoveryConfig = IZkEmailRecovery
            .RecoveryConfig(newRecoveryModule, newDelay, newExpiry);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        vm.startPrank(accountAddress);
        zkEmailRecovery.updateRecoveryConfig(recoveryConfig);

        recoveryConfig = zkEmailRecovery.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.recoveryModule, newRecoveryModule);
        assertEq(recoveryConfig.delay, newDelay);
        assertEq(recoveryConfig.expiry, newExpiry);
    }
}
