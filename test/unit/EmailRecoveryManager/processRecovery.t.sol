// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract EmailRecoveryManager_processRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;

    string calldataHashString;
    bytes[] subjectParams;
    bytes32 nullifier;

    function setUp() public override {
        super.setUp();

        calldataHashString = uint256(calldataHash).toHexString(32);
        subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(recoveryModuleAddress);
        subjectParams[2] = abi.encode(calldataHashString);
        nullifier = keccak256(abi.encode("nullifier 1"));
    }

    function test_ProcessRecovery_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(IEmailRecoveryManager.InvalidTemplateIndex.selector);
        emailRecoveryManager.exposed_processRecovery(
            guardian1, invalidTemplateIdx, subjectParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsNONE() public {
        address invalidGuardian = address(1);

        // invalidGuardian has not been configured nor accepted, so the guardian status is NONE
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.NONE),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        emailRecoveryManager.exposed_processRecovery(
            invalidGuardian, templateIdx, subjectParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsREQUESTED() public {
        // Valid guardian but we haven't called acceptGuardian(), so the guardian
        // status is still REQUESTED
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.REQUESTED),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        emailRecoveryManager.exposed_processRecovery(
            guardian1, templateIdx, subjectParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_RecoveryModuleNotInstalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.exposed_processRecovery(
            guardian1, templateIdx, subjectParams, nullifier
        );
    }

    function test_ProcessRecovery_IncreasesTotalWeight() public {
        uint256 guardian1Weight = guardianWeights[0];

        acceptGuardian(accountSalt1);

        emailRecoveryManager.exposed_processRecovery(
            guardian1, templateIdx, subjectParams, nullifier
        );

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryManager.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, guardian1Weight);
        assertEq(recoveryRequest.calldataHash, "");
    }

    function test_ProcessRecovery_InitiatesRecovery() public {
        uint256 guardian1Weight = guardianWeights[0];
        uint256 guardian2Weight = guardianWeights[1];

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        // Call processRecovery - increases currentWeight to 1 so not >= threshold yet
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        // Call processRecovery with guardian2 which increases currentWeight to >= threshold
        emailRecoveryManager.exposed_processRecovery(
            guardian2, templateIdx, subjectParams, nullifier
        );

        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryManager.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, guardian1Weight + guardian2Weight);
        assertEq(recoveryRequest.calldataHash, calldataHash);
    }
}
