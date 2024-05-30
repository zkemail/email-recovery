// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract ZkEmailRecovery_processRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, recoveryModuleAddress)
        });
        // Install recovery module - configureRecovery is called on `onInstall`
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(address(validator), guardians, guardianWeights, threshold, delay, expiry)
        });
    }

    function test_ProcessRecovery_RevertWhen_InvalidGuardianAddress() public {
        address invalidGuardian = address(0);

        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        vm.expectRevert(IZkEmailRecovery.InvalidGuardian.selector);
        zkEmailRecovery.exposed_processRecovery(
            invalidGuardian, templateIdx, subjectParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        vm.expectRevert(IZkEmailRecovery.InvalidTemplateIndex.selector);
        zkEmailRecovery.exposed_processRecovery(
            guardian1, invalidTemplateIdx, subjectParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsNONE() public {
        address invalidGuardian = address(1);

        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        // invalidGuardian has not been configured nor accepted, so the guardian status is NONE
        vm.expectRevert(
            abi.encodeWithSelector(
                IZkEmailRecovery.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.NONE),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        zkEmailRecovery.exposed_processRecovery(
            invalidGuardian, templateIdx, subjectParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsREQUESTED() public {
        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        // Valid guardian but we haven't called acceptGuardian(), so the guardian status is still
        // REQUESTED
        vm.expectRevert(
            abi.encodeWithSelector(
                IZkEmailRecovery.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.REQUESTED),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        zkEmailRecovery.exposed_processRecovery(guardian1, templateIdx, subjectParams, nullifier);
    }

    function test_ProcessRecovery_IncreasesTotalWeight() public {
        uint256 guardian1Weight = guardianWeights[0];

        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        acceptGuardian(accountSalt1);

        zkEmailRecovery.exposed_processRecovery(guardian1, templateIdx, subjectParams, nullifier);

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, guardian1Weight);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }

    function test_ProcessRecovery_InitiatesRecovery() public {
        uint256 guardian1Weight = guardianWeights[0];
        uint256 guardian2Weight = guardianWeights[1];

        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        // Call processRecovery - increases currentWeight to 1 so not >= threshold yet
        handleRecovery(recoveryModuleAddress, accountSalt1);

        // Call processRecovery with guardian2 which increases currentWeight to >= threshold
        zkEmailRecovery.exposed_processRecovery(guardian2, templateIdx, subjectParams, nullifier);

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, guardian1Weight + guardian2Weight);
        assertEq(recoveryRequest.subjectParams.length, 3);
        assertEq(recoveryRequest.subjectParams[0], subjectParams[0]);
        assertEq(recoveryRequest.subjectParams[1], subjectParams[1]);
        assertEq(recoveryRequest.subjectParams[2], subjectParams[2]);
    }

    function test_ProcessRecovery_CompletesRecoveryIfDelayIsZero() public {
        uint256 zeroDelay = 0 seconds;

        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(newOwner);
        subjectParams[2] = abi.encode(recoveryModuleAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        // Since configureRecovery is already called in `onInstall`, we update the delay to be 0
        // here
        vm.prank(accountAddress);
        zkEmailRecovery.updateRecoveryConfig(
            IZkEmailRecovery.RecoveryConfig(recoveryModuleAddress, zeroDelay, expiry)
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        // Call processRecovery - increases currentWeight to 1 so not >= threshold yet
        handleRecovery(recoveryModuleAddress, accountSalt1);

        // Call processRecovery with guardian2 which increases currentWeight to >= threshold
        zkEmailRecovery.exposed_processRecovery(guardian2, templateIdx, subjectParams, nullifier);

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }
}
