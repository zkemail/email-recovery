// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_acceptGuardian_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    bytes[] subjectParams;
    bytes32 nullifier;

    function setUp() public override {
        super.setUp();

        subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);
        nullifier = keccak256(abi.encode("nullifier 1"));
    }

    function test_AcceptGuardian_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(IEmailRecoveryManager.InvalidTemplateIndex.selector);
        emailRecoveryManager.exposed_acceptGuardian(
            guardian1, invalidTemplateIdx, subjectParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        emailRecoveryManager.exposed_acceptGuardian(
            guardian1, templateIdx, subjectParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_RecoveryModuleNotInstalled() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.RecoveryModuleNotInstalled.selector);
        emailRecoveryManager.exposed_acceptGuardian(
            guardian1, templateIdx, subjectParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_GuardianStatusIsNONE() public {
        address invalidGuardian = address(1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.NONE),
                uint256(GuardianStatus.REQUESTED)
            )
        );
        emailRecoveryManager.exposed_acceptGuardian(
            invalidGuardian, templateIdx, subjectParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_GuardianStatusIsACCEPTED() public {
        emailRecoveryManager.exposed_acceptGuardian(
            guardian1, templateIdx, subjectParams, nullifier
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.ACCEPTED),
                uint256(GuardianStatus.REQUESTED)
            )
        );
        emailRecoveryManager.exposed_acceptGuardian(
            guardian1, templateIdx, subjectParams, nullifier
        );
    }

    function test_AcceptGuardian_Succeeds() public {
        emailRecoveryManager.exposed_acceptGuardian(
            guardian1, templateIdx, subjectParams, nullifier
        );

        GuardianStorage memory guardianStorage =
            emailRecoveryManager.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));
    }
}
