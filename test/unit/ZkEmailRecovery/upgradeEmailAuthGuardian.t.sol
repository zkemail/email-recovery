// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";

contract ZkEmailRecovery_upgradeEmailAuthGuardian_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_UpgradeEmailAuthGuardian_RevertWhen_UnauthorizedAccountForGuardian() public {
        address newImplementation = address(1);
        bytes memory data = "";

        vm.expectRevert(IZkEmailRecovery.UnauthorizedAccountForGuardian.selector);
        zkEmailRecovery.upgradeEmailAuthGuardian(guardian1, newImplementation, data);
    }

    function test_UpgradeEmailAuthGuardian_RevertWhen_RecoveryInProcess() public {
        address newImplementation = address(1);
        bytes memory data = "";

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.upgradeEmailAuthGuardian(guardian1, newImplementation, data);
    }

    function test_UpgradeEmailAuthGuardian_Succeeds() public {
        EmailAuth newEmailAuth = new EmailAuth();
        address newImplementation = address(newEmailAuth);
        bytes memory data;

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);

        vm.startPrank(accountAddress);
        zkEmailRecovery.upgradeEmailAuthGuardian(guardian1, newImplementation, data);
    }
}
