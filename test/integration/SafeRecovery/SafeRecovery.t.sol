// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { SafeIntegrationBase } from "./SafeIntegrationBase.t.sol";

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
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.currentWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecoveryForSafe(accountAddress1, owner1, newOwner1, guardians1[1]);
        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryModule.completeRecovery(accountAddress1, recoveryData);

        recoveryRequest = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);

        vm.prank(accountAddress1);
        bool isOwner = Safe(payable(accountAddress1)).isOwner(newOwner1);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(accountAddress1)).isOwner(owner1);
        assertFalse(oldOwnerIsOwner);
    }

    // FIXME: This test cannot uninstall the module - reverts with no error message
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
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    //     assertEq(recoveryRequest.commandParams.length, 0);

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
