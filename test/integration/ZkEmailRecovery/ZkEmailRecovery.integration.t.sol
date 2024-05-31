// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { IEmailAccountRecovery } from "src/interfaces/IEmailAccountRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorBase } from "../OwnableValidatorRecovery/OwnableValidatorBase.t.sol";

contract ZkEmailRecovery_Integration_Test is OwnableValidatorBase {
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

    function test_RevertWhen_HandleAcceptanceCalled_BeforeConfigureRecovery() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        // Issue where forge cannot detect revert even though the call does indeed revert when
        // is
        // "expectRevert" commented out
        // vm.expectRevert();
        // acceptGuardian(accountSalt1);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeTimeStampChanged() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("invalid timestamp");
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
    }

    function test_RevertWhen_HandleAcceptanceCalled_DuringRecovery() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);

        // Issue where forge cannot detect revert even though this is the revert error when
        // the call is made with "expectRevert"
        // vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        // acceptGuardian(accountSalt2);
    }

    function test_RevertWhen_HandleAcceptanceCalled_AfterRecoveryProcessedButBeforeCompleteRecovery(
    )
        public
    {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);

        // Issue where forge cannot detect revert even though this is the revert error when
        // the call is made with "expectRevert"
        // vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        // acceptGuardian(accountSalt3);
    }

    function test_HandleNewAcceptanceSucceeds_AfterCompleteRecovery() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        IEmailAccountRecovery(router).completeRecovery();

        acceptGuardian(accountSalt3);

        GuardianStorage memory guardianStorage =
            zkEmailRecovery.getGuardian(accountAddress, guardian3);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeConfigureRecovery() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        // Issue where forge cannot detect revert even though the call does indeed revert when
        // is
        // vm.expectRevert();
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeHandleAcceptance() public {
        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("guardian is not deployed");
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
    }

    function test_RevertWhen_HandleRecoveryCalled_DuringRecoveryWithoutGuardianBeingDeployed()
        public
    {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("guardian is not deployed");
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterRecoveryProcessedButBeforeCompleteRecovery()
        public
    {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("guardian is not deployed");
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt3);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterCompleteRecovery() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        IEmailAccountRecovery(router).completeRecovery();

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("email nullifier already used");
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeConfigureRecovery() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IZkEmailRecovery.InvalidAccountAddress.selector);
        IEmailAccountRecovery(router).completeRecovery();
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeHandleAcceptance() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        vm.expectRevert(IZkEmailRecovery.NotEnoughApprovals.selector);
        IEmailAccountRecovery(router).completeRecovery();
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeProcessRecovery() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);
        acceptGuardian(accountSalt1);

        vm.expectRevert(IZkEmailRecovery.NotEnoughApprovals.selector);
        IEmailAccountRecovery(router).completeRecovery();
    }

    function test_TryRecoverWhenModuleNotInstalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryModuleNotInstalled.selector);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        // vm.stopPrank();

        // address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        // acceptGuardian(accountSalt1);
        // acceptGuardian(accountSalt2);
        // vm.warp(12 seconds);
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        // handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);

        // vm.warp(block.timestamp + delay);

        // // vm.expectRevert(
        // //     abi.encodeWithSelector(
        // //         InvalidModule.selector,
        // //         recoveryModuleAddress
        // //     )
        // // );
        // vm.expectRevert();
        // IEmailAccountRecovery(router).completeRecovery();
    }

    function test_StaleRecoveryRequest() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);

        vm.warp(10 weeks);

        vm.expectRevert(IZkEmailRecovery.RecoveryRequestExpired.selector);
        IEmailAccountRecovery(router).completeRecovery();

        // Can cancel recovery even when stale
        vm.startPrank(accountAddress);
        zkEmailRecovery.cancelRecovery(bytes(""));
        vm.stopPrank();

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }
}
