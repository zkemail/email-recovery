// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorRecoveryBase } from "./OwnableValidatorRecoveryBase.t.sol";

contract OwnableValidatorRecovery_Integration_Test is OwnableValidatorRecoveryBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RotatesOwnerSuccessfully() public {
        // Accept guardian 1
        acceptGuardian(accountAddress1, guardian1);
        GuardianStorage memory guardianStorage1 =
            emailRecoveryManager.getGuardian(accountAddress1, guardian1);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian 2
        acceptGuardian(accountAddress1, guardian2);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryManager.getGuardian(accountAddress1, guardian2);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);
        // handle recovery request for guardian 1
        handleRecovery(accountAddress1, guardian1, calldataHash1);
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryManager.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecovery(accountAddress1, guardian2, calldataHash1);
        recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryManager.completeRecovery(accountAddress1, recoveryCalldata1);

        recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress1);
        address updatedOwner = validator.owners(accountAddress1);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(updatedOwner, newOwner1);
    }

    function test_Recover_CannotMixAccountHandleAcceptance() public {
        acceptGuardian(accountAddress1, guardian1);
        acceptGuardian(accountAddress2, guardian2);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardian1, calldataHash1);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardian2, calldataHash1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                GuardianStatus.REQUESTED,
                GuardianStatus.ACCEPTED
            )
        );
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_Recover_CannotMixAccountHandleRecovery() public {
        acceptGuardian(accountAddress1, guardian1);
        acceptGuardian(accountAddress1, guardian2);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardian1, calldataHash1);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress2, guardian2, calldataHash2);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                GuardianStatus.REQUESTED,
                GuardianStatus.ACCEPTED
            )
        );
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    // Helper function
    function executeRecoveryFlowForAccount(
        address account,
        bytes memory recoveryCalldata
    )
        internal
    {
        acceptGuardian(account, guardian1);
        acceptGuardian(account, guardian2);
        vm.warp(12 seconds);
        handleRecovery(account, guardian1, calldataHash1);
        handleRecovery(account, guardian2, calldataHash1);
        vm.warp(block.timestamp + delay);
        emailRecoveryManager.completeRecovery(account, recoveryCalldata);
    }

    function test_Recover_RotatesMultipleOwnersSuccessfully() public {
        executeRecoveryFlowForAccount(accountAddress1, recoveryCalldata1);

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(accountAddress2, guardian1);

        // FIXME: Should not fail here
        vm.expectRevert("template id already exists");
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }
}
