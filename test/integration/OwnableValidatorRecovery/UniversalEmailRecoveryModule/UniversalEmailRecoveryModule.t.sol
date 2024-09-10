// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorRecovery_UniversalEmailRecoveryModule_Base } from
    "./UniversalEmailRecoveryModuleBase.t.sol";

contract OwnableValidatorRecovery_UniversalEmailRecoveryModule_Integration_Test is
    OwnableValidatorRecovery_UniversalEmailRecoveryModule_Base
{
    using ModuleKitHelpers for *;

    // Helper function
    function executeRecoveryFlowForAccount(
        address account,
        address[] memory guardians,
        bytes32 recoveryDataHash,
        bytes memory recoveryData
    )
        internal
    {
        acceptGuardian(account, guardians[0]);
        acceptGuardian(account, guardians[1]);
        vm.warp(block.timestamp + 12 seconds);
        handleRecovery(account, guardians[0], recoveryDataHash);
        handleRecovery(account, guardians[1], recoveryDataHash);
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(account, recoveryData);
    }

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
        uint256 executeBefore = block.timestamp + expiry;
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);
        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash1);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData1);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        address updatedOwner = validator.owners(accountAddress1);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.recoveryDataHash, bytes32(0));
        assertEq(updatedOwner, newOwner1);
    }

    function test_Recover_RevertWhen_MixAccountHandleAcceptance() public {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardianWithAccountSalt(accountAddress2, guardians1[1], accountSalt2);
        vm.warp(12 seconds);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[1], recoveryDataHash1);

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);

        emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[0], recoveryDataHash1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.ThresholdExceedsAcceptedWeight.selector, 3, 1
            )
        );
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_MixAccountHandleRecovery() public {
        acceptGuardianWithAccountSalt(accountAddress2, guardians1[1], accountSalt2);

        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessageWithAccountSalt(
            accountAddress2, guardians1[1], recoveryDataHash2, accountSalt2
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.ThresholdExceedsAcceptedWeight.selector,
                uint256(3),
                uint256(2)
            )
        );
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_UninstallModuleBeforeAnyGuardiansAccepted() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(accountAddress1, guardians1[0]);

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_UninstallModuleBeforeEnoughAcceptedAndTryHandleAcceptance()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0]);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(accountAddress1, guardians1[1]);

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_UninstallModuleAfterEnoughAcceptedAndTryHandleRecovery()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[0], recoveryDataHash1);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_UninstallModuleAfterOneApprovalAndTryHandleRecovery() public {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.onUninstall("");
    }

    function test_Recover_RevertWhen_UninstallModuleProcessRecoveryAndTryCompleteRecovery()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        handleRecovery(accountAddress1, guardians1[1], recoveryDataHash1);
        vm.warp(block.timestamp + delay);

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.onUninstall("");
    }

    function test_Recover_RevertWhen_UninstallModuleAndTryRecoveryAgain() public {
        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner1 = validator.owners(accountAddress1);
        assertEq(updatedOwner1, newOwner1);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(accountAddress1, guardians1[0]);

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_Recover_UninstallModuleAndRecoverAgain() public {
        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner = validator.owners(accountAddress1);
        assertEq(updatedOwner, newOwner1);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                validatorAddress,
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });

        bytes memory newChangeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory newRecoveryData = abi.encode(validatorAddress, newChangeOwnerCalldata);
        bytes32 newRecoveryDataHash = keccak256(newRecoveryData);
        executeRecoveryFlowForAccount(
            accountAddress1, guardians1, newRecoveryDataHash, newRecoveryData
        );

        updatedOwner = validator.owners(accountAddress1);
        assertEq(updatedOwner, newOwner2);
    }

    function test_Recover_RotatesMultipleOwnersSuccessfully() public {
        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        executeRecoveryFlowForAccount(accountAddress2, guardians2, recoveryDataHash2, recoveryData2);
        executeRecoveryFlowForAccount(accountAddress3, guardians3, recoveryDataHash3, recoveryData3);

        address updatedOwner1 = validator.owners(accountAddress1);
        address updatedOwner2 = validator.owners(accountAddress2);
        address updatedOwner3 = validator.owners(accountAddress3);
        assertEq(updatedOwner1, newOwner1);
        assertEq(updatedOwner2, newOwner2);
        assertEq(updatedOwner3, newOwner3);
    }

    function test_Recover_RecoversSameValidatorAgain() public {
        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner1 = validator.owners(accountAddress1);
        assertEq(updatedOwner1, newOwner1);

        bytes memory newChangeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory newValidatorRecoveryData = abi.encode(validatorAddress, newChangeOwnerCalldata);
        bytes32 newValidatorRecoveryDataHash = keccak256(newValidatorRecoveryData);

        handleRecovery(accountAddress1, guardians1[0], newValidatorRecoveryDataHash);
        handleRecovery(accountAddress1, guardians1[1], newValidatorRecoveryDataHash);
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(accountAddress1, newValidatorRecoveryData);

        address updatedOwner2 = validator.owners(accountAddress1);
        assertEq(updatedOwner2, newOwner2);
    }

    function test_Recover_RevertWhen_RecoversMultipleValidatorsOneAfterTheOtherWithoutAllowingValidator(
    )
        public
    {
        OwnableValidator validator2 = new OwnableValidator();
        address validator2Address = address(validator2);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validator2Address,
            data: abi.encode(owner2)
        });

        bytes memory newChangeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory validator2RecoveryData = abi.encode(validator2Address, newChangeOwnerCalldata);
        bytes32 validator2RecoveryDataHash = keccak256(validator2RecoveryData);

        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner1 = validator.owners(accountAddress1);
        assertEq(updatedOwner1, newOwner1);

        handleRecovery(accountAddress1, guardians1[0], validator2RecoveryDataHash);
        handleRecovery(accountAddress1, guardians1[1], validator2RecoveryDataHash);
        vm.warp(block.timestamp + delay);

        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, functionSelector
            )
        );
        emailRecoveryModule.completeRecovery(accountAddress1, validator2RecoveryData);
    }

    function test_Recover_RecoversMultipleValidatorsOneAfterTheOther() public {
        OwnableValidator validator2 = new OwnableValidator();
        address validator2Address = address(validator2);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validator2Address,
            data: abi.encode(owner2)
        });
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(validator2Address, "", functionSelector);
        vm.stopPrank();

        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner1 = validator.owners(accountAddress1);
        assertEq(updatedOwner1, newOwner1);

        bytes memory newChangeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory validator2RecoveryData = abi.encode(validator2Address, newChangeOwnerCalldata);
        bytes32 validator2RecoveryDataHash = keccak256(validator2RecoveryData);

        handleRecovery(accountAddress1, guardians1[0], validator2RecoveryDataHash);
        handleRecovery(accountAddress1, guardians1[1], validator2RecoveryDataHash);
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(accountAddress1, validator2RecoveryData);

        address updatedOwner2 = validator2.owners(accountAddress1);
        assertEq(updatedOwner2, newOwner2);
    }

    function test_Recover_RevertWhen_RecoversMultipleValidatorsAtOnce() public {
        OwnableValidator validator2 = new OwnableValidator();
        address validator2Address = address(validator2);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validator2Address,
            data: abi.encode(owner2)
        });

        bytes memory newChangeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory validator2RecoveryData = abi.encode(validatorAddress, newChangeOwnerCalldata);
        bytes32 validator2RecoveryDataHash = keccak256(validator2RecoveryData);

        // Accept guardians
        acceptGuardian(accountAddress1, guardians1[0]);
        acceptGuardian(accountAddress1, guardians1[1]);
        vm.warp(block.timestamp + 12 seconds);

        // process recovery for validator 1
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash1);
        vm.warp(block.timestamp + 12 seconds);

        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(accountAddress1, guardians1[0], validator2RecoveryDataHash);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidRecoveryDataHash.selector,
                validator2RecoveryDataHash,
                recoveryDataHash1
            )
        );
        // process recovery for validator 2
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }
}
