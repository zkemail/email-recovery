// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ModuleKitHelpers, AccountInstance} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {EmailAuthMsg} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import {EmailAccountRecovery} from "@zk-email/ether-email-auth-contracts/src/EmailAccountRecovery.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IEmailRecoveryManager} from "src/interfaces/IEmailRecoveryManager.sol";
import {IGuardianManager} from "src/interfaces/IGuardianManager.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";

import {CommandHandlerType, GuardianType} from "./GuardianVerifierBase.t.sol";
import {OwnableValidatorRecovery_AbstractedRecoveryModule_Base} from "./GuardianVerifierBase.t.sol";

/**
 * Test the abstracted recovery module with email based guardians
 */
contract OwnableValidatorRecovery_AbstractedRecoveryModule_Test is
    OwnableValidatorRecovery_AbstractedRecoveryModule_Base
{
    using ModuleKitHelpers for *;
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    // Helper function
    function executeRecoveryFlowForAccount(
        address account,
        address[] memory guardians,
        bytes32 recoveryDataHash,
        bytes memory recoveryData
    ) internal {
        acceptGuardian(
            GuardianType.EmailGuardian,
            emailGuardianVerifierImplementation,
            account,
            guardians[0],
            emailRecoveryModuleAddress,
            accountSalt1,
            emailGuardianVerifierInitData
        );
        acceptGuardian(
            GuardianType.EmailNrGuardian,
            emailGuardianNrVerifierImplementation,
            account,
            guardians[1],
            emailRecoveryModuleAddress,
            accountSalt2,
            emailGuardianNrVerifierInitData
        );

        vm.warp(block.timestamp + 12 seconds);
        handleRecovery(
            GuardianType.EmailGuardian,
            account,
            guardians[0],
            recoveryDataHash,
            emailRecoveryModuleAddress,
            accountSalt1
        );
        handleRecovery(
            GuardianType.EmailNrGuardian,
            account,
            guardians[1],
            recoveryDataHash,
            emailRecoveryModuleAddress,
            accountSalt1
        );
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(account, recoveryData);
    }

    // End to end test
    function test_Recover_RotatesOwnerSuccessfully() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        // Accept guardian 1 - email
        acceptGuardian(
            GuardianType.EmailGuardian,
            emailGuardianVerifierImplementation,
            accountAddress1,
            guardians1[0],
            emailRecoveryModuleAddress,
            accountSalt1,
            emailGuardianVerifierInitData
        );
        GuardianStorage memory guardianStorage1 = emailRecoveryModule
            .getGuardian(accountAddress1, guardians1[0]);
        assertEq(
            uint256(guardianStorage1.status),
            uint256(GuardianStatus.ACCEPTED)
        );
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian 2
        acceptGuardian(
            GuardianType.EmailNrGuardian,
            emailGuardianNrVerifierImplementation,
            accountAddress1,
            guardians1[1],
            emailRecoveryModuleAddress,
            accountSalt2,
            emailGuardianNrVerifierInitData
        );

        GuardianStorage memory guardianStorage2 = emailRecoveryModule
            .getGuardian(accountAddress1, guardians1[1]);
        assertEq(
            uint256(guardianStorage2.status),
            uint256(GuardianStatus.ACCEPTED)
        );
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        handleRecovery(
            GuardianType.EmailGuardian,
            accountAddress1,
            guardians1[0],
            recoveryDataHash1,
            emailRecoveryModuleAddress,
            accountSalt1
        );
        uint256 executeBefore = block.timestamp + expiry;
        (
            uint256 _executeAfter,
            uint256 _executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(
            accountAddress1,
            guardians1[0]
        );
        bool hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(
            accountAddress1,
            guardians1[1]
        );
        assertEq(_executeAfter, 0);
        assertEq(_executeBefore, executeBefore);
        assertEq(currentWeight, 1);
        assertEq(recoveryDataHash, recoveryDataHash1);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, false);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        handleRecovery(
            GuardianType.EmailNrGuardian,
            accountAddress1,
            guardians1[1],
            recoveryDataHash1,
            emailRecoveryModuleAddress,
            accountSalt2
        );
        (
            _executeAfter,
            _executeBefore,
            currentWeight,
            recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(
            accountAddress1,
            guardians1[0]
        );
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(
            accountAddress1,
            guardians1[1]
        );
        assertEq(_executeAfter, executeAfter);
        assertEq(_executeBefore, executeBefore);
        assertEq(currentWeight, 3);
        assertEq(recoveryDataHash, recoveryDataHash1);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        (
            _executeAfter,
            _executeBefore,
            currentWeight,
            recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(
            accountAddress1,
            guardians1[0]
        );
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(
            accountAddress1,
            guardians1[1]
        );
        address updatedOwner = validator.owners(accountAddress1);

        assertEq(_executeAfter, 0);
        assertEq(_executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(recoveryDataHash, bytes32(0));
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(updatedOwner, newOwner1);
    }
}
