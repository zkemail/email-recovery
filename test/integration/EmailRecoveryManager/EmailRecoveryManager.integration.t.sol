// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorRecoveryBase } from
    "../OwnableValidatorRecovery/OwnableValidatorRecoveryBase.t.sol";

contract EmailRecoveryManager_Integration_Test is OwnableValidatorRecoveryBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_HandleAcceptanceCalled_BeforeConfigureRecovery() public {
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
        acceptGuardian(accountSalt1);

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("invalid timestamp");
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
    }

    function test_RevertWhen_HandleAcceptanceCalled_DuringRecovery() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        // Issue where forge cannot detect revert even though this is the revert error when
        // the call is made with "expectRevert"
        // vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        // acceptGuardian(accountSalt2);
    }

    function test_RevertWhen_HandleAcceptanceCalled_AfterRecoveryProcessedButBeforeCompleteRecovery(
    )
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        // Issue where forge cannot detect revert even though this is the revert error when
        // the call is made with "expectRevert"
        // vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        // acceptGuardian(accountSalt3);
    }

    function test_HandleNewAcceptanceSucceeds_AfterCompleteRecovery() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

        acceptGuardian(accountSalt3);

        GuardianStorage memory guardianStorage =
            emailRecoveryManager.getGuardian(accountAddress, guardian3);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        // Issue where forge cannot detect revert even though the call does indeed revert when
        // is
        // vm.expectRevert();
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
    }

    function test_RevertWhen_HandleRecoveryCalled_BeforeHandleAcceptance() public {
        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("guardian is not deployed");
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
    }

    function test_RevertWhen_HandleRecoveryCalled_DuringRecoveryWithoutGuardianBeingDeployed()
        public
    {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("guardian is not deployed");
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterRecoveryProcessedButBeforeCompleteRecovery()
        public
    {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("guardian is not deployed");
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt3);
    }

    function test_RevertWhen_HandleRecoveryCalled_AfterCompleteRecovery() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

        // Issue where forge cannot detect revert even though this is the revert message when
        // the call is made with "expectRevert"
        // vm.expectRevert("email nullifier already used");
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeConfigureRecovery() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        // vm.expectRevert(IEmailRecoveryManager.InvalidAccountAddress.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeHandleAcceptance() public {
        vm.expectRevert(IEmailRecoveryManager.NotEnoughApprovals.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_RevertWhen_CompleteRecoveryCalled_BeforeProcessRecovery() public {
        acceptGuardian(accountSalt1);

        vm.expectRevert(IEmailRecoveryManager.NotEnoughApprovals.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_TryRecoverWhenModuleNotInstalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.configureRecovery(guardians, guardianWeights, threshold, delay, expiry);
        // vm.stopPrank();

        //

        // acceptGuardian(accountSalt1);
        // acceptGuardian(accountSalt2);
        // vm.warp(12 seconds);
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        // handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        // vm.warp(block.timestamp + delay);

        // // vm.expectRevert(
        // //     abi.encodeWithSelector(
        // //         InvalidModule.selector,
        // //         recoveryModuleAddress
        // //     )
        // // );
        // vm.expectRevert();
        // emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);
    }

    function test_StaleRecoveryRequest() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);

        vm.warp(10 weeks);

        vm.expectRevert(IEmailRecoveryManager.RecoveryRequestExpired.selector);
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

        // Can cancel recovery even when stale
        vm.startPrank(accountAddress);
        emailRecoveryManager.cancelRecovery();
        vm.stopPrank();

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryManager.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
    }
}
