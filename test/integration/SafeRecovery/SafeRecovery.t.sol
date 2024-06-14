// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "erc7579/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { SafeIntegrationBase } from "./SafeIntegrationBase.t.sol";

contract SafeRecovery_Integration_Test is SafeIntegrationBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    EmailRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    bytes4 functionSelector;

    // function setUp() public override {
    //     super.setUp();
    //     recoveryModule = new EmailRecoveryModule(address(emailRecoveryManager));
    //     recoveryModuleAddress = address(recoveryModule);

    //     functionSelector = bytes4(keccak256(bytes("changeOwner(address,address,address)")));

    //     instance.installModule({
    //         moduleTypeId: MODULE_TYPE_EXECUTOR,
    //         module: recoveryModuleAddress,
    //         data: abi.encode(
    //             address(safe), // FIXME: requires rhinestone change
    //             functionSelector,
    //             guardians,
    //             guardianWeights,
    //             threshold,
    //             delay,
    //             expiry
    //         )
    //     });
    // }

    // function test_Recover_RotatesOwnerSuccessfully() public {
    //     IERC7579Account account = IERC7579Account(accountAddress);
    //     bytes memory recoveryCalldata = abi.encodeWithSignature(
    //         "changeOwner(address,address,address)", accountAddress, recoveryModuleAddress,
    // newOwner
    //     );
    //     bytes32 calldataHash = keccak256(recoveryCalldata);

    //     bytes[] memory subjectParamsForRecovery = new bytes[](4);
    //     subjectParamsForRecovery[0] = abi.encode(accountAddress);
    //     subjectParamsForRecovery[1] = abi.encode(owner);
    //     subjectParamsForRecovery[2] = abi.encode(newOwner);
    //     subjectParamsForRecovery[3] = abi.encode(recoveryModuleAddress);

    //     // // Install recovery module - configureRecovery is called on `onInstall`
    //     // vm.prank(accountAddress);
    //     // account.installModule(
    //     //     MODULE_TYPE_EXECUTOR,
    //     //     recoveryModuleAddress,
    //     //     abi.encode(guardians, guardianWeights, threshold, delay, expiry)
    //     // );
    //     // vm.stopPrank();

    //     // Accept guardian
    //     acceptGuardian(accountSalt1);
    //     GuardianStorage memory guardianStorage1 =
    //         emailRecoveryManager.getGuardian(accountAddress, guardian1);
    //     assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
    //     assertEq(guardianStorage1.weight, uint256(1));

    //     // Accept guardian
    //     acceptGuardian(accountSalt2);
    //     GuardianStorage memory guardianStorage2 =
    //         emailRecoveryManager.getGuardian(accountAddress, guardian2);
    //     assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
    //     assertEq(guardianStorage2.weight, uint256(2));

    //     // Time travel so that EmailAuth timestamp is valid
    //     vm.warp(12 seconds);

    //     // handle recovery request for guardian 1
    //     handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.currentWeight, 1);

    //     // handle recovery request for guardian 2
    //     uint256 executeAfter = block.timestamp + delay;
    //     uint256 executeBefore = block.timestamp + expiry;
    //     handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);
    //     recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, executeAfter);
    //     assertEq(recoveryRequest.executeBefore, executeBefore);
    //     assertEq(recoveryRequest.currentWeight, 3);

    //     vm.warp(block.timestamp + delay);

    //     // Complete recovery
    //     emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

    //     recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);

    //     vm.prank(accountAddress);
    //     bool isOwner = Safe(payable(accountAddress)).isOwner(newOwner);
    //     assertTrue(isOwner);

    //     bool oldOwnerIsOwner = Safe(payable(accountAddress)).isOwner(owner);
    //     assertFalse(oldOwnerIsOwner);
    // }

    // FIXME: This test cannot uninstall the module - reverts with no error message
    // function test_OnUninstall_DeInitsStateSuccessfully() public {
    //     // configure and complete an entire recovery request
    //     test_Recover_RotatesOwnerSuccessfully();
    //     address router = emailRecoveryManager.computeRouterAddress(
    //         keccak256(abi.encode(accountAddress))
    //     );
    //     IERC7579Account account = IERC7579Account(accountAddress);

    //     // Uninstall module
    //     vm.prank(accountAddress);
    //     account.uninstallModule(
    //         MODULE_TYPE_EXECUTOR,
    //         recoveryModuleAddress,
    //         ""
    //     );
    //     vm.stopPrank();

    //     // bool isModuleInstalled = account.isModuleInstalled(
    //     //     MODULE_TYPE_EXECUTOR,
    //     //     address(recoveryModule),
    //     //     ""
    //     // );
    //     // assertFalse(isModuleInstalled);

    //     // assert that recovery config has been cleared successfully
    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig = emailRecoveryManager
    //         .getRecoveryConfig(accountAddress);
    //     assertEq(recoveryConfig.recoveryModule, address(0));
    //     assertEq(recoveryConfig.delay, 0);
    //     assertEq(recoveryConfig.expiry, 0);

    //     // assert that the recovery request has been cleared successfully
    //     IEmailRecoveryManager.RecoveryRequest
    //         memory recoveryRequest = emailRecoveryManager.getRecoveryRequest(
    //             accountAddress
    //         );
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    //     assertEq(recoveryRequest.subjectParams.length, 0);

    //     // assert that guardian storage has been cleared successfully for guardian 1
    //     GuardianStorage memory guardianStorage1 = emailRecoveryManager.getGuardian(
    //         accountAddress,
    //         guardian1
    //     );
    //     assertEq(
    //         uint256(guardianStorage1.status),
    //         uint256(GuardianStatus.NONE)
    //     );
    //     assertEq(guardianStorage1.weight, uint256(0));

    //     // assert that guardian storage has been cleared successfully for guardian 2
    //     GuardianStorage memory guardianStorage2 = emailRecoveryManager.getGuardian(
    //         accountAddress,
    //         guardian2
    //     );
    //     assertEq(
    //         uint256(guardianStorage2.status),
    //         uint256(GuardianStatus.NONE)
    //     );
    //     assertEq(guardianStorage2.weight, uint256(0));

    //     // assert that guardian config has been cleared successfully
    //     IEmailRecoveryManager.GuardianConfig memory guardianConfig = emailRecoveryManager
    //         .getGuardianConfig(accountAddress);
    //     assertEq(guardianConfig.guardianCount, 0);
    //     assertEq(guardianConfig.totalWeight, 0);
    //     assertEq(guardianConfig.threshold, 0);

    //     // assert that the recovery router mappings have been cleared successfully
    //     address accountForRouter = emailRecoveryManager.getAccountForRouter(router);
    //     address routerForAccount = emailRecoveryManager.getRouterForAccount(
    //         accountAddress
    //     );
    //     assertEq(accountForRouter, address(0));
    //     assertEq(routerForAccount, address(0));
    // }
}
