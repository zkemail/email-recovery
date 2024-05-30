// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

// completeRecovery()
contract ZkEmailRecovery_completeRecovery_Test is UnitBase {
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

    function test_CompleteRecovery_RevertWhen_NotCalledFromCorrectRouter() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + delay);

        vm.expectRevert(IZkEmailRecovery.InvalidAccountAddress.selector);
        zkEmailRecovery.completeRecovery();
    }

    function test_CompleteRecovery_Succeeds() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + delay);

        vm.prank(router);
        zkEmailRecovery.completeRecovery();

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }
}

// completeRecovery(address account)
contract ZkEmailRecovery_completeRecoveryWithAddress_Test is UnitBase {
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

    function test_CompleteRecovery_RevertWhen_InvalidAccountAddress() public {
        address invalidAccount = address(0);

        vm.expectRevert(IZkEmailRecovery.InvalidAccountAddress.selector);
        zkEmailRecovery.completeRecovery(invalidAccount);
    }

    function test_CompleteRecovery_RevertWhen_NotEnoughApprovals() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1); // only one guardian added and one
            // approval

        vm.expectRevert(IZkEmailRecovery.NotEnoughApprovals.selector);
        zkEmailRecovery.completeRecovery(accountAddress);
    }

    function test_CompleteRecovery_RevertWhen_DelayNotPassed() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + delay - 1 seconds); // one second before it should be valid

        vm.expectRevert(IZkEmailRecovery.DelayNotPassed.selector);
        zkEmailRecovery.completeRecovery(accountAddress);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampEqualToExpiry()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + expiry); // block.timestamp == recoveryRequest.executeBefore

        vm.expectRevert(IZkEmailRecovery.RecoveryRequestExpired.selector);
        zkEmailRecovery.completeRecovery(accountAddress);
    }

    function test_CompleteRecovery_RevertWhen_RecoveryRequestExpiredAndTimestampMoreThanExpiry()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + expiry + 1 seconds); // block.timestamp >
            // recoveryRequest.executeBefore

        vm.expectRevert(IZkEmailRecovery.RecoveryRequestExpired.selector);
        zkEmailRecovery.completeRecovery(accountAddress);
    }

    function test_CompleteRecovery_CompleteRecovery_Succeeds() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + delay);

        vm.expectEmit();
        emit IZkEmailRecovery.RecoveryCompleted(accountAddress);
        zkEmailRecovery.completeRecovery(accountAddress);

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }

    function test_CompleteRecovery_SucceedsAlmostExpiry() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + expiry - 1 seconds);

        vm.expectEmit();
        emit IZkEmailRecovery.RecoveryCompleted(accountAddress);
        zkEmailRecovery.completeRecovery(accountAddress);

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }
}
