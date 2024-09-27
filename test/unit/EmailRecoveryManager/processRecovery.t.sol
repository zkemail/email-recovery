// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract EmailRecoveryManager_processRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;

    string public recoveryDataHashString;
    bytes[] public commandParams;
    bytes32 public nullifier;

    function setUp() public override {
        super.setUp();

        recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
        commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(recoveryDataHashString);
        nullifier = keccak256(abi.encode("nullifier 1"));
    }

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsNONE() public {
        address invalidGuardian = address(1);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        // invalidGuardian has not been configured nor accepted, so the guardian status is NONE
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.NONE),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            invalidGuardian, templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsREQUESTED() public {
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);

        // Valid guardian but we haven't called acceptGuardian(), so the guardian
        // status is still REQUESTED
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.REQUESTED),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_RecoveryModuleNotInstalled() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_ThresholdExceedsAcceptedWeight() public {
        // total weight = 4
        // threshold = 3
        // useable weight from accepted guardians = 0

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress); // weight = 1
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress); // weight = 2

        // total weight = 4
        // threshold = 3
        // useable weight from accepted guardians = 3

        address newGuardian = address(1);
        uint256 newWeight = 1;
        uint256 newThreshold = 5;

        vm.startPrank(accountAddress1);
        emailRecoveryModule.addGuardian(newGuardian, newWeight);
        emailRecoveryModule.changeThreshold(newThreshold);
        vm.stopPrank();
        // total weight = 5
        // threshold = 5
        // useable weight from accepted guardians = 3

        vm.warp(12 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.ThresholdExceedsAcceptedWeight.selector, newThreshold, 3
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_InvalidRecoveryDataHash() public {
        bytes32 invalidRecoveryDataHash = keccak256(abi.encode("invalid hash"));
        string memory invalidRecoveryDataHashString =
            uint256(invalidRecoveryDataHash).toHexString(32);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        commandParams[1] = abi.encode(invalidRecoveryDataHashString);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidRecoveryDataHash.selector,
                invalidRecoveryDataHash,
                recoveryDataHash
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianMustWaitForCooldown() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.warp(block.timestamp + expiry);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.GuardianMustWaitForCooldown.selector, guardians1[0]
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_IncreasesTotalWeight() public {
        uint256 guardian1Weight = guardianWeights[0];

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        // IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
        //     emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, 0);
        // assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        // assertEq(recoveryRequest.currentWeight, guardian1Weight);
        // assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);
    }

    function test_ProcessRecovery_InitiatesRecovery() public {
        uint256 guardian1Weight = guardianWeights[0];
        uint256 guardian2Weight = guardianWeights[1];

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        // Call processRecovery - increases currentWeight to 1 so not >= threshold yet
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        // Call processRecovery with guardians2 which increases currentWeight to >= threshold
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryProcessed(
            accountAddress1,
            guardians1[1],
            block.timestamp + delay,
            block.timestamp + expiry,
            recoveryDataHash
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );

        // IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
        //     emailRecoveryModule.getRecoveryRequest(accountAddress1);
        // assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        // assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        // assertEq(recoveryRequest.currentWeight, guardian1Weight + guardian2Weight);
        // assertEq(recoveryRequest.recoveryDataHash, recoveryDataHash);
    }
}
