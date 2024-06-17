// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract ZkEmailRecovery_processRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_ProcessRecovery_RevertWhen_GuardianStatusIsNONE() public {
    //     address invalidGuardian = address(1);

    //     bytes[] memory subjectParams = new bytes[](3);
    //     subjectParams[0] = abi.encode(accountAddress);
    //     subjectParams[1] = abi.encode(newOwner);
    //     subjectParams[2] = abi.encode(recoveryModuleAddress);
    //     bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

    //     // invalidGuardian has not been configured nor accepted, so the guardian status is NONE
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEmailRecoveryManager.InvalidGuardianStatus.selector,
    //             uint256(GuardianStatus.NONE),
    //             uint256(GuardianStatus.ACCEPTED)
    //         )
    //     );
    //     emailRecoveryManager.exposed_processRecovery(
    //         invalidGuardian, templateIdx, subjectParams, nullifier
    //     );
    // }

    // function test_ProcessRecovery_RevertWhen_GuardianStatusIsREQUESTED() public {
    //     bytes[] memory subjectParams = new bytes[](3);
    //     subjectParams[0] = abi.encode(accountAddress);
    //     subjectParams[1] = abi.encode(newOwner);
    //     subjectParams[2] = abi.encode(recoveryModuleAddress);
    //     bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

    //     // Valid guardian but we haven't called acceptGuardian(), so the guardian status is still
    //     // REQUESTED
    //     vm.expectRevert(
    //         abi.encodeWithSelector(
    //             IEmailRecoveryManager.InvalidGuardianStatus.selector,
    //             uint256(GuardianStatus.REQUESTED),
    //             uint256(GuardianStatus.ACCEPTED)
    //         )
    //     );
    //     emailRecoveryManager.exposed_processRecovery(
    //         guardian1, templateIdx, subjectParams, nullifier
    //     );
    // }

    // function test_ProcessRecovery_IncreasesTotalWeight() public {
    //     uint256 guardian1Weight = guardianWeights[0];

    //     bytes[] memory subjectParams = new bytes[](3);
    //     subjectParams[0] = abi.encode(accountAddress);
    //     subjectParams[1] = abi.encode(newOwner);
    //     subjectParams[2] = abi.encode(recoveryModuleAddress);
    //     bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

    //     acceptGuardian(accountSalt1);

    //     emailRecoveryManager.exposed_processRecovery(
    //         guardian1, templateIdx, subjectParams, nullifier
    //     );

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, guardian1Weight);
    // }

    // function test_ProcessRecovery_InitiatesRecovery() public {
    //     uint256 guardian1Weight = guardianWeights[0];
    //     uint256 guardian2Weight = guardianWeights[1];

    //     bytes[] memory subjectParams = new bytes[](3);
    //     subjectParams[0] = abi.encode(accountAddress);
    //     subjectParams[1] = abi.encode(newOwner);
    //     subjectParams[2] = abi.encode(recoveryModuleAddress);
    //     bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     // Call processRecovery - increases currentWeight to 1 so not >= threshold yet
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     // Call processRecovery with guardian2 which increases currentWeight to >= threshold
    //     emailRecoveryManager.exposed_processRecovery(
    //         guardian2, templateIdx, subjectParams, nullifier
    //     );

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
    //     assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
    //     assertEq(recoveryRequest.currentWeight, guardian1Weight + guardian2Weight);
    // }

    // function test_ProcessRecovery_CompletesRecoveryIfDelayIsZero() public {
    //     uint256 zeroDelay = 0 seconds;

    //     bytes[] memory subjectParams = new bytes[](3);
    //     subjectParams[0] = abi.encode(accountAddress);
    //     subjectParams[1] = abi.encode(newOwner);
    //     subjectParams[2] = abi.encode(recoveryModuleAddress);
    //     bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

    //     // Since configureRecovery is already called in `onInstall`, we update the delay to be 0
    //     // here
    //     vm.prank(accountAddress);
    //     emailRecoveryManager.updateRecoveryConfig(
    //         IEmailRecoveryManager.RecoveryConfig(zeroDelay, expiry)
    //     );
    //     vm.stopPrank();

    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);
    //     vm.warp(12 seconds);
    //     // Call processRecovery - increases currentWeight to 1 so not >= threshold yet
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     // Call processRecovery with guardian2 which increases currentWeight to >= threshold
    //     emailRecoveryManager.exposed_processRecovery(
    //         guardian2, templateIdx, subjectParams, nullifier
    //     );

    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);
    // }
}
