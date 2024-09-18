// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianManager } from "src/GuardianManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_acceptGuardian_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    bytes[] commandParams;
    bytes32 nullifier;

    function setUp() public override {
        super.setUp();

        commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress1);
        nullifier = keccak256(abi.encode("nullifier 1"));
    }

    function test_AcceptGuardian_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(recoveryDataHash, accountSalt1);

        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_RecoveryModuleNotInstalled() public {
        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.stopPrank();

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
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
        emailRecoveryModule.exposed_acceptGuardian(
            invalidGuardian, templateIdx, commandParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_GuardianStatusIsACCEPTED() public {
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.ACCEPTED),
                uint256(GuardianStatus.REQUESTED)
            )
        );
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_AcceptGuardian_Succeeds() public {
        vm.expectEmit();
        emit IEmailRecoveryManager.GuardianAccepted(accountAddress1, guardians1[0]);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage.weight, uint256(1));

        IGuardianManager.GuardianConfig memory guardianConfig =
            emailRecoveryModule.getGuardianConfig(accountAddress1);
        assertEq(guardianConfig.acceptedWeight, guardianStorage.weight);
    }
}
