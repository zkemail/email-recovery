// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorRecovery_EmailRecoveryModule_Base } from "./EmailRecoveryModuleBase.t.sol";

contract OwnableValidatorRecovery_EmailRecoveryModule_Integration_Test is
    OwnableValidatorRecovery_EmailRecoveryModule_Base
{
    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RotatesOwnerSuccessfully() public {
        // Accept guardian 1
        acceptGuardian(accountAddress1, guardians1[0]);
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian 2
        acceptGuardian(accountAddress1, guardians1[1]);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);
        // handle recovery request for guardian 1
        handleRecovery(accountAddress1, guardians1[0], calldataHash1);
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecovery(accountAddress1, guardians1[1], calldataHash1);
        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryCalldata1);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        address updatedOwner = validator.owners(accountAddress1);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(updatedOwner, newOwner1);
    }

    // function test_Recover_CannotMixAccountHandleAcceptance() public {
    //     acceptGuardian(accountAddress1, guardians1[0]);
    //     acceptGuardian(accountAddress2, guardians2[1]);
    //     vm.warp(12 seconds);
    //     handleRecovery(accountAddress1, guardians1[0], calldataHash1);

    //     EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
    //         accountAddress1,
    //         guardians1[1],
    //         calldataHash1
    //     );

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEmailRecoveryManager.InvalidGuardianStatus.selector,
    //             GuardianStatus.REQUESTED,
    //             GuardianStatus.ACCEPTED
    //         )
    //     );
    //     emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    // }

    // function test_Recover_CannotMixAccountHandleRecovery() public {
    //     acceptGuardian(accountAddress1, guardians1[0]);
    //     acceptGuardian(accountAddress1, guardians1[1]);
    //     vm.warp(12 seconds);
    //     handleRecovery(accountAddress1, guardians1[0], calldataHash1);

    //     EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
    //         accountAddress2,
    //         guardians1[1],
    //         calldataHash2
    //     );

    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEmailRecoveryManager.InvalidGuardianStatus.selector,
    //             GuardianStatus.REQUESTED,
    //             GuardianStatus.ACCEPTED
    //         )
    //     );
    //     emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    // }

    // Helper function
    function executeRecoveryFlowForAccount(
        address account,
        bytes32 calldataHash,
        bytes memory recoveryCalldata
    )
        internal
    {
        acceptGuardian(account, guardians1[0]);
        acceptGuardian(account, guardians1[1]);
        vm.warp(block.timestamp + 12 seconds);
        handleRecovery(account, guardians1[0], calldataHash);
        handleRecovery(account, guardians1[1], calldataHash);
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(account, recoveryCalldata);
    }

    // function test_Recover_RotatesMultipleOwnersSuccessfully() public {
    //     executeRecoveryFlowForAccount(
    //         accountAddress1,
    //         calldataHash1,
    //         recoveryCalldata1
    //     );
    //     vm.warp(block.timestamp + 12 seconds);
    //     executeRecoveryFlowForAccount(
    //         accountAddress2,
    //         calldataHash2,
    //         recoveryCalldata2
    //     );
    //     vm.warp(block.timestamp + 12 seconds);
    //     executeRecoveryFlowForAccount(
    //         accountAddress3,
    //         calldataHash3,
    //         recoveryCalldata3
    //     );

    //     address updatedOwner1 = validator.owners(accountAddress1);
    //     address updatedOwner2 = validator.owners(accountAddress2);
    //     address updatedOwner3 = validator.owners(accountAddress3);
    //     assertEq(updatedOwner1, newOwner1);
    //     assertEq(updatedOwner2, newOwner2);
    //     assertEq(updatedOwner3, newOwner3);
    // }

    // function test_Recover_RevertWhen_InvalidTimestamp() public {
    //     acceptGuardian(accountAddress1, guardians1[0]);
    //     EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
    //         accountAddress2,
    //         guardians2[0]
    //     );

    //     vm.expectRevert("invalid timestamp");
    //     emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    // }
}
