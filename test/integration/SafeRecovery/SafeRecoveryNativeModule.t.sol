// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { SafeNativeIntegrationBase } from "./SafeNativeIntegrationBase.t.sol";

contract SafeRecoveryNativeModule_Integration_Test is SafeNativeIntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function testIntegration_AccountRecovery() public {
        skipIfNotSafeAccountType();

        address newOwner1 = owner2;
        // Configure recovery
        vm.startPrank(safeAddress);
        emailRecoveryModule.configureSafeRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        bytes memory recoveryCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", address(1), owner1, newOwner1
        );
        bytes memory recoveryData = abi.encode(safeAddress, recoveryCalldata);
        bytes32 recoveryDataHash = keccak256(recoveryData);

        AccountHidingRecoveryCommandHandler(commandHandler).storeAccountHash(safeAddress);

        // Accept guardian
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            safeAddress, guardians1[0], emailRecoveryModuleAddress, accountSalt1
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(safeAddress, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian
        emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            safeAddress, guardians1[1], emailRecoveryModuleAddress, accountSalt2
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(safeAddress, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        uint256 executeBefore = block.timestamp + expiry;
        emailAuthMsg = getRecoveryEmailAuthMessage(safeAddress, recoveryDataHash, guardians1[0]);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(safeAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        emailAuthMsg = getRecoveryEmailAuthMessage(safeAddress, recoveryDataHash, guardians1[1]);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        recoveryRequest = emailRecoveryModule.getRecoveryRequest(safeAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryModule.completeRecovery(safeAddress, recoveryData);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(safeAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, bytes32(0));

        vm.prank(safeAddress);
        bool isOwner = Safe(payable(safeAddress)).isOwner(newOwner1);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(safeAddress)).isOwner(owner1);
        assertFalse(oldOwnerIsOwner);
    }

    function testIntegration_AccountRecovery_UninstallsModule() public {
        testIntegration_AccountRecovery();

        bool isModuleEnabled =
            Safe(payable(safeAddress)).isModuleEnabled(emailRecoveryModuleAddress);
        assertTrue(isModuleEnabled);

        // Uninstall module
        // instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.prank(safeAddress);
        Safe(payable(safeAddress)).disableModule(address(1), emailRecoveryModuleAddress);
        vm.stopPrank();

        isModuleEnabled = Safe(payable(safeAddress)).isModuleEnabled(emailRecoveryModuleAddress);
        assertFalse(isModuleEnabled);

        vm.prank(safeAddress);
        emailRecoveryModule.resetWhenDisabled(safeAddress);
        vm.stopPrank();
    }
}
