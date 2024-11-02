// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, AccountInstance } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailAccountRecovery } from
    "@zk-email/ether-email-auth-contracts/src/EmailAccountRecovery.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

import { CommandHandlerType } from "../../../Base.t.sol";
import { OwnableValidatorRecovery_EmailRecoveryModule_Base } from "./EmailRecoveryModuleBase.t.sol";

contract OwnableValidatorRecovery_EmailRecoveryModule_Integration_Test is
    OwnableValidatorRecovery_EmailRecoveryModule_Base
{
    using ModuleKitHelpers for *;
    using Strings for uint256;

    // Helper function
    function executeRecoveryFlowForAccount(
        address account,
        address[] memory guardians,
        bytes32 recoveryDataHash,
        bytes memory recoveryData
    )
        internal
    {
        acceptGuardian(account, guardians[0], emailRecoveryModuleAddress);
        acceptGuardian(account, guardians[1], emailRecoveryModuleAddress);
        vm.warp(block.timestamp + 12 seconds);
        handleRecovery(account, guardians[0], recoveryDataHash, emailRecoveryModuleAddress);
        handleRecovery(account, guardians[1], recoveryDataHash, emailRecoveryModuleAddress);
        vm.warp(block.timestamp + delay);
        emailRecoveryModule.completeRecovery(account, recoveryData);
    }

    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RotatesOwnerSuccessfully() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        // Accept guardian 1
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian 2
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);
        // handle recovery request for guardian 1
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        uint256 executeBefore = block.timestamp + expiry;
        (
            uint256 _executeAfter,
            uint256 _executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(_executeAfter, 0);
        assertEq(_executeBefore, executeBefore);
        assertEq(currentWeight, 1);
        assertEq(recoveryDataHash, recoveryDataHash1);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, false);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
        (_executeAfter, _executeBefore, currentWeight, recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
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

        (_executeAfter, _executeBefore, currentWeight, recoveryDataHash) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        address updatedOwner = validator.owners(accountAddress1);

        assertEq(_executeAfter, 0);
        assertEq(_executeBefore, 0);
        assertEq(currentWeight, 0);
        assertEq(recoveryDataHash, bytes32(0));
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);
        assertEq(updatedOwner, newOwner1);
    }

    function test_Recover_RevertWhen_MixAccountHandleAcceptance() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardianWithAccountSalt(
            accountAddress2, guardians1[1], emailRecoveryModuleAddress, accountSalt2
        );
        vm.warp(12 seconds);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert("guardian is not deployed");
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);

        emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.ThresholdExceedsAcceptedWeight.selector, 3, 1
            )
        );
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_MixAccountHandleRecovery() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardianWithAccountSalt(
            accountAddress2, guardians1[1], emailRecoveryModuleAddress, accountSalt2
        );

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(block.timestamp + 12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessageWithAccountSalt(
            accountAddress2,
            guardians1[1],
            recoveryDataHash2,
            emailRecoveryModuleAddress,
            accountSalt2
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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress
        );

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_UninstallModuleBeforeEnoughAcceptedAndTryHandleAcceptance()
        public
    {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[1], emailRecoveryModuleAddress
        );

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_UninstallModuleAfterEnoughAcceptedAndTryHandleRecovery()
        public
    {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);

        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessage(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function test_Recover_RevertWhen_UninstallModuleAfterOneApprovalAndTryHandleRecovery() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.onUninstall("");
    }

    function test_Recover_RevertWhen_UninstallModuleProcessRecoveryAndTryCompleteRecovery()
        public
    {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(
            accountAddress1, guardians1[0], recoveryDataHash1, emailRecoveryModuleAddress
        );
        handleRecovery(
            accountAddress1, guardians1[1], recoveryDataHash1, emailRecoveryModuleAddress
        );
        vm.warp(block.timestamp + delay);

        vm.startPrank(accountAddress1);
        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.onUninstall("");
    }

    function test_Recover_RevertWhen_UninstallModuleAndTryRecoveryAgain() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner1 = validator.owners(accountAddress1);
        assertEq(updatedOwner1, newOwner1);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(
            accountAddress1, guardians1[0], emailRecoveryModuleAddress
        );

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function test_Recover_UninstallModuleAndRecoverAgain() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner = validator.owners(accountAddress1);
        assertEq(updatedOwner, newOwner1);

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
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
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

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

    function test_ActivateKillSwitchDoesNotImpactOtherModules() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        bytes32 commandHandlerSalt = bytes32(uint256(1));
        bytes32 recoveryModuleSalt = bytes32(uint256(1));
        (address newRecoveryModuleAddress,) = emailRecoveryFactory.deployEmailRecoveryModule(
            commandHandlerSalt,
            recoveryModuleSalt,
            getHandlerBytecode(),
            minimumDelay,
            killSwitchAuthorizer,
            address(dkimRegistry),
            validatorAddress,
            functionSelector
        );
        AccountInstance memory newAccountInstance = makeAccountInstance("account1");
        newAccountInstance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: newRecoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
        });

        vm.prank(killSwitchAuthorizer);
        IEmailRecoveryManager(newRecoveryModuleAddress).toggleKillSwitch();
        vm.stopPrank();

        // toggling kill switch for one module does not inpact other modules
        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);

        // new module should not be useable
        vm.expectRevert(IEmailRecoveryManager.KillSwitchEnabled.selector);
        EmailAccountRecovery(newRecoveryModuleAddress).completeRecovery(
            accountAddress1, abi.encodePacked("1")
        );
        executeRecoveryFlowForAccount(accountAddress2, guardians2, recoveryDataHash2, recoveryData2);
        executeRecoveryFlowForAccount(accountAddress3, guardians3, recoveryDataHash3, recoveryData3);

        address updatedOwner1 = validator.owners(accountAddress1);
        address updatedOwner2 = validator.owners(accountAddress2);
        address updatedOwner3 = validator.owners(accountAddress3);
        assertEq(updatedOwner1, newOwner1);
        assertEq(updatedOwner2, newOwner2);
        assertEq(updatedOwner3, newOwner3);
    }

    function test_Recover_RevertWhenUninstallModuleAndRecoverAgainWithKillSwitch() public {
        skipIfCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);
        string memory currentAccountType = vm.envOr("ACCOUNT_TYPE", string(""));
        if (bytes(currentAccountType).length == 0 || Strings.equal(currentAccountType, "DEFAULT")) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }

        executeRecoveryFlowForAccount(accountAddress1, guardians1, recoveryDataHash1, recoveryData1);
        address updatedOwner = validator.owners(accountAddress1);
        assertEq(updatedOwner, newOwner1);

        vm.prank(killSwitchAuthorizer);
        IEmailRecoveryManager(emailRecoveryModuleAddress).toggleKillSwitch();
        vm.stopPrank();

        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        // the second module installation should fail after the kill switch is enabled.
        instance1.expect4337Revert(IEmailRecoveryManager.KillSwitchEnabled.selector);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
        });
    }
}
