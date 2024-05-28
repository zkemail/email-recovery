// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_acceptGuardian_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_AcceptGuardian_RevertWhen_InvalidGuardianAddress() public {
        address invalidGuardian = address(0);

        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = "";

        vm.expectRevert(IZkEmailRecovery.InvalidGuardian.selector);
        zkEmailRecovery.exposed_acceptGuardian(
            invalidGuardian,
            templateIdx,
            subjectParams,
            nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = "";

        vm.expectRevert(IZkEmailRecovery.InvalidTemplateIndex.selector);
        zkEmailRecovery.exposed_acceptGuardian(
            guardian1,
            invalidTemplateIdx,
            subjectParams,
            nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_AlreadyRecovering() public {
        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(
            accountAddress,
            zkEmailRecovery,
            router,
            "Accept guardian request for 0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52",
            keccak256(abi.encode("nullifier 1")),
            accountSalt1,
            templateIdx
        );

        vm.warp(12 seconds);

        handleRecovery(
            accountAddress,
            newOwner,
            recoveryModuleAddress,
            router,
            zkEmailRecovery,
            "Recover account 0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x94Ebc11100A3c5741500D3fe6d16EEDEa254EADe",
            keccak256(abi.encode("nullifier 2")),
            accountSalt1,
            templateIdx
        );

        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = "";

        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.exposed_acceptGuardian(
            guardian1,
            templateIdx,
            subjectParams,
            nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_InvalidGuardianStatus() public {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = "";

        vm.expectRevert(
            abi.encodeWithSelector(
                IZkEmailRecovery.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.NONE),
                uint256(GuardianStatus.REQUESTED)
            )
        );
        zkEmailRecovery.exposed_acceptGuardian(
            guardian1,
            templateIdx,
            subjectParams,
            nullifier
        );
    }

    function test_AcceptGuardian_Succeeds() public {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        bytes32 nullifier = "";

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        zkEmailRecovery.exposed_acceptGuardian(
            guardian1,
            templateIdx,
            subjectParams,
            nullifier
        );

        GuardianStorage memory guardianStorage = zkEmailRecovery.getGuardian(
            accountAddress,
            guardian1
        );
        assertEq(
            uint256(guardianStorage.status),
            uint256(GuardianStatus.ACCEPTED)
        );
        assertEq(guardianStorage.weight, uint256(1));
    }
}
