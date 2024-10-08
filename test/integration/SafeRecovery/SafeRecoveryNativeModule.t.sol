// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { SafeNativeIntegrationBase } from "./SafeNativeIntegrationBase.t.sol";
import { CommandHandlerType } from "../../Base.t.sol";

contract SafeRecoveryNativeModule_Integration_Test is SafeNativeIntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function testIntegration_AccountRecovery() public {
        skipIfNotSafeAccountType();
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        // Configure recovery
        vm.startPrank(accountAddress1);
        emailRecoveryModule.configureSafeRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        // Accept guardian
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress, accountSalt1
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian
        emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            accountAddress1, guardians1[1], emailRecoveryModuleAddress, accountSalt2
        );
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        uint256 executeBefore = block.timestamp + expiry;
        emailAuthMsg = getRecoveryEmailAuthMessage(accountAddress1, recoveryDataHash, guardians1[0]);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        (
            uint256 _executeAfter,
            uint256 _executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(_executeAfter, 0);
        assertEq(_executeBefore, executeBefore);
        assertEq(currentWeight, 1);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, false);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        emailAuthMsg = getRecoveryEmailAuthMessage(accountAddress1, recoveryDataHash, guardians1[1]);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        (_executeAfter, _executeBefore, currentWeight, _recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(_executeAfter, executeAfter);
        assertEq(_executeBefore, executeBefore);
        assertEq(currentWeight, 3);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);

        (_executeAfter, _executeBefore, currentWeight, _recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(_executeAfter, 0);
        assertEq(_executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, bytes32(0));
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);

        vm.prank(accountAddress1);
        bool isOwner = Safe(payable(accountAddress1)).isOwner(newOwner1);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(accountAddress1)).isOwner(owner1);
        assertFalse(oldOwnerIsOwner);
    }

    function testIntegration_AccountRecovery_UninstallsModule() public {
        testIntegration_AccountRecovery();

        bool isModuleEnabled =
            Safe(payable(accountAddress1)).isModuleEnabled(emailRecoveryModuleAddress);
        assertTrue(isModuleEnabled);

        // Uninstall module
        vm.prank(accountAddress1);
        Safe(payable(accountAddress1)).disableModule(address(1), emailRecoveryModuleAddress);
        vm.stopPrank();

        isModuleEnabled = Safe(payable(accountAddress1)).isModuleEnabled(emailRecoveryModuleAddress);
        assertFalse(isModuleEnabled);

        vm.prank(accountAddress1);
        emailRecoveryModule.resetWhenDisabled(accountAddress1);
        vm.stopPrank();
    }
}
