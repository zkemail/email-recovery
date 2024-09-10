// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "erc7579/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { SafeProxy } from "@safe-global/safe-contracts/contracts/proxies/SafeProxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { AccountHidingRecoverySubjectHandler } from
    "src/handlers/AccountHidingRecoverySubjectHandler.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { SafeNativeIntegrationBase } from "./SafeNativeIntegrationBase.t.sol";

contract SafeRecoveryNativeModule_Integration_Test is SafeNativeIntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function testIntegration_AccountRecovery() public {
        skipIfNotSafeAccountType();

        address newOwner = owner2;
        // Configure recovery
        vm.startPrank(safeAddress);
        emailRecoveryModule.configureRecovery(guardians1, guardianWeights, threshold, delay, expiry);
        vm.stopPrank();

        bytes memory recoveryCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", address(1), owner, newOwner
        );
        bytes memory recoveryData = abi.encode(safeAddress, recoveryCalldata);
        bytes32 recoveryDataHash = keccak256(recoveryData);

        bytes32 accountHash = keccak256(abi.encodePacked(safeAddress));

        AccountHidingRecoverySubjectHandler(subjectHandler).storeAccountHash(safeAddress);

        // Accept guardian
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(safeAddress, guardians1[0]);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(safeAddress, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian
        emailAuthMsg = getAcceptanceEmailAuthMessage(safeAddress, guardians1[1]);
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
        bool isOwner = Safe(payable(safeAddress)).isOwner(newOwner);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(safeAddress)).isOwner(owner);
        assertFalse(oldOwnerIsOwner);
    }

    function testIntegration_AccountRecovery_UninstallsModule() public {
        testIntegration_AccountRecovery();

        bool isModuleEnabled =
            Safe(payable(safeAddress)).isModuleEnabled(emailRecoveryModuleAddress);
        assertTrue(isModuleEnabled);

        // Uninstall module
        // instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
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
