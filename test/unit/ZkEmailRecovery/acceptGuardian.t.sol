// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract ZkEmailRecovery_acceptGuardian_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_AcceptGuardian_RevertWhen_AlreadyRecovering() public {
        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.exposed_acceptGuardian(guardian1, templateIdx, subjectParams, nullifier);
    }

    function test_AcceptGuardian_RevertWhen_GuardianStatusIsNONE() public {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        vm.expectRevert(
            abi.encodeWithSelector(
                IZkEmailRecovery.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.NONE),
                uint256(GuardianStatus.REQUESTED)
            )
        );
        zkEmailRecovery.exposed_acceptGuardian(guardian1, templateIdx, subjectParams, nullifier);
    }

    function test_AcceptGuardian_RevertWhen_GuardianStatusIsACCEPTED() public {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        zkEmailRecovery.exposed_acceptGuardian(guardian1, templateIdx, subjectParams, nullifier);

        vm.expectRevert(
            abi.encodeWithSelector(
                IZkEmailRecovery.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.ACCEPTED),
                uint256(GuardianStatus.REQUESTED)
            )
        );
        zkEmailRecovery.exposed_acceptGuardian(guardian1, templateIdx, subjectParams, nullifier);
    }

    function test_AcceptGuardian_Succeeds() public {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        zkEmailRecovery.exposed_acceptGuardian(guardian1, templateIdx, subjectParams, nullifier);

        GuardianStorage memory guardianStorage =
            zkEmailRecovery.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));
    }
}
