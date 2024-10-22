// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";

contract EmailRecoveryManager_clearRecoveryRequest_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ClearRecoveryRequest_DoesNotRevertWhenInvalidAccount() public {
        emailRecoveryModule.exposed_clearRecoveryRequest(address(0));
        emailRecoveryModule.exposed_clearRecoveryRequest(address(1));
    }

    function test_ClearRecoveryRequest_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(executeAfter, block.timestamp + delay);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 3);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);

        emailRecoveryModule.exposed_clearRecoveryRequest(accountAddress1);

        // assert that the recovery request has been cleared successfully
        (executeAfter, executeBefore, currentWeight, _recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, "");
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);

        uint256 voteCount = emailRecoveryModule.workaround_getVoteCount(accountAddress1);
        assertEq(voteCount, 0);
    }

    function test_ClearRecoveryRequest_SucceedsWithMaxGuardians() public {
        // There are already 3 guardians configured, and the maximum number of guardians is 32
        address[] memory guardians = new address[](29);

        for (uint256 i = 0; i < 29; i++) {
            guardians[i] = computeEmailAuthAddress(instance1.account, keccak256(abi.encode(i)));
        }

        // The total number of guardians is now 32, which is the maximum number
        vm.startPrank(accountAddress1);
        for (uint256 i = 0; i < 29; i++) {
            emailRecoveryModule.addGuardian(guardians[i], 1);
        }
        vm.stopPrank();

        // first 3 guardians that are already configured
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);

        // Next 29 guardians that have just been created
        for (uint256 i = 0; i < 29; i++) {
            acceptGuardianWithAccountSalt(
                accountAddress1, guardians[i], emailRecoveryModuleAddress, keccak256(abi.encode(i))
            );
        }
        vm.warp(block.timestamp + 12 seconds);

        // first 3 guardians that are already configured
        vm.warp(block.timestamp + 12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(accountAddress1, guardians1[2], recoveryDataHash, emailRecoveryModuleAddress);

        // Next 29 guardians that have just been created
        for (uint256 i = 0; i < 29; i++) {
            handleRecoveryWithAccountSalt(
                accountAddress1,
                guardians[i],
                recoveryDataHash,
                emailRecoveryModuleAddress,
                keccak256(abi.encode(i))
            );
        }

        uint256 guardianCount = emailRecoveryModule.getGuardianConfig(accountAddress1).guardianCount;
        assertEq(guardianCount, 32);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        bool hasGuardian3Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(executeAfter, block.timestamp + delay);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 33); // pre-configured guardian 2 has a weight of 2, so the total is
            // one more than 32
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertTrue(hasGuardian1Voted);
        assertTrue(hasGuardian2Voted);
        assertTrue(hasGuardian3Voted);
        for (uint256 i = 0; i < 29; i++) {
            assertTrue(emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians[i]));
        }

        emailRecoveryModule.exposed_clearRecoveryRequest(accountAddress1);

        // assert that the recovery request has been cleared successfully
        (executeAfter, executeBefore, currentWeight, _recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        previousRecoveryRequest = emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        hasGuardian3Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[2]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(_recoveryDataHash, "");
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, 0);
        assertFalse(hasGuardian1Voted);
        assertFalse(hasGuardian2Voted);
        assertFalse(hasGuardian3Voted);
        for (uint256 i = 0; i < 29; i++) {
            assertFalse(emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians[i]));
        }

        uint256 voteCount = emailRecoveryModule.workaround_getVoteCount(accountAddress1);
        assertEq(voteCount, 0);
    }
}
