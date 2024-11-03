// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";

import { SafeIntegrationBase } from "./SafeIntegrationBase.t.sol";
import { CommandHandlerType } from "../../Base.t.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract SafeRecovery_Integration_Test is SafeIntegrationBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RotatesOwnerSuccessfully() public {
        if (!isAccountTypeSafe()) {
            vm.skip(true);
        }
        skipIfNotCommandHandlerType(CommandHandlerType.SafeRecoveryCommandHandler);

        bytes memory swapOwnerCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", address(1), owner1, newOwner1
        );
        bytes memory recoveryData = abi.encode(accountAddress1, swapOwnerCalldata);

        bytes[] memory commandParamsForRecovery = new bytes[](3);
        commandParamsForRecovery[0] = abi.encode(accountAddress1);
        commandParamsForRecovery[1] = abi.encode(owner1);
        commandParamsForRecovery[2] = abi.encode(newOwner1);

        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);

        // Accept guardian
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        guardianStorage1 = emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        handleRecoveryForSafe(accountAddress1, owner1, newOwner1, guardians1[0]);
        (,, uint256 currentWeight,) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        assertEq(currentWeight, 1);
        assertEq(hasGuardian1Voted, true);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecoveryForSafe(accountAddress1, owner1, newOwner1, guardians1[1]);
        (uint256 _executeAfter, uint256 _executeBefore, uint256 currentWeight2,) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(_executeAfter, executeAfter);
        assertEq(_executeBefore, executeBefore);
        assertEq(currentWeight2, 3);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);

        (_executeAfter, _executeBefore, currentWeight2,) =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        hasGuardian1Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        hasGuardian2Voted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(_executeAfter, 0);
        assertEq(_executeBefore, 0);
        assertEq(currentWeight2, 0);
        assertEq(hasGuardian1Voted, false);
        assertEq(hasGuardian2Voted, false);

        vm.prank(accountAddress1);
        bool isOwner = Safe(payable(accountAddress1)).isOwner(newOwner1);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(accountAddress1)).isOwner(owner1);
        assertFalse(oldOwnerIsOwner);
    }

    // FIXME: (merge-ok) This test cannot uninstall the module - reverts with no error message
    // function test_OnUninstall_DeInitsStateSuccessfully() public {
    //     // configure and complete an entire recovery request
    //     test_Recover_RotatesOwnerSuccessfully();
    //     address router =
    //         emailRecoveryModule.computeRouterAddress(keccak256(abi.encode(accountAddress1)));
    //     IERC7579Account account = IERC7579Account(accountAddress1);

    //     // Uninstall module
    //     vm.prank(accountAddress1);
    //     account.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
    //     vm.stopPrank();

    //     // bool isModuleInstalled = account.isModuleInstalled(
    //     //     MODULE_TYPE_EXECUTOR,
    //     //     address(recoveryModule),
    //     //     ""
    //     // );
    //     // assertFalse(isModuleInstalled);

    //     // assert that recovery config has been cleared successfully
    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         emailRecoveryModule.getRecoveryConfig(accountAddress1);
    //     assertEq(recoveryConfig.recoveryModule, address(0));
    //     assertEq(recoveryConfig.delay, 0);
    //     assertEq(recoveryConfig.expiry, 0);

    //     // assert that the recovery request has been cleared successfully
    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryModule.getRecoveryRequest(accountAddress1);
    //     assertEq(executeAfter, 0);
    //     assertEq(executeBefore, 0);
    //     assertEq(currentWeight, 0);
    //     assertEq(commandParams.length, 0);

    //     // assert that guardian storage has been cleared successfully for guardian 1
    //     GuardianStorage memory guardianStorage1 =
    //         emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
    //     assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
    //     assertEq(guardianStorage1.weight, uint256(0));

    //     // assert that guardian storage has been cleared successfully for guardian 2
    //     GuardianStorage memory guardianStorage2 =
    //         emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
    //     assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
    //     assertEq(guardianStorage2.weight, uint256(0));

    //     // assert that guardian config has been cleared successfully
    //     GuardianManager.GuardianConfig memory guardianConfig =
    //         emailRecoveryModule.getGuardianConfig(accountAddress1);
    //     assertEq(guardianConfig.guardianCount, 0);
    //     assertEq(guardianConfig.totalWeight, 0);
    //     assertEq(guardianConfig.threshold, 0);

    //     // assert that the recovery router mappings have been cleared successfully
    //     address accountForRouter = emailRecoveryModule.getAccountForRouter(router);
    //     address routerForAccount = emailRecoveryModule.getRouterForAccount(accountAddress1);
    //     assertEq(accountForRouter, address(0));
    //     assertEq(routerForAccount, address(0));
    // }
}
