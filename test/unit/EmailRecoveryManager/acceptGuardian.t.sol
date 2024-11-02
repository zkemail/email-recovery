// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { CommandHandlerType } from "../../Base.t.sol";

contract EmailRecoveryManager_acceptGuardian_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;

    bytes[] public commandParams;
    bytes32 public nullifier;

    function setUp() public override {
        super.setUp();

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            commandParams = new bytes[](1);
            commandParams[0] =
                abi.encode(uint256(keccak256(abi.encodePacked(accountAddress1))).toHexString(32));
        } else {
            commandParams = new bytes[](1);
            commandParams[0] = abi.encode(accountAddress1);
        }

        nullifier = keccak256(abi.encode("nullifier 1"));
    }

    function test_AcceptGuardian_RevertWhen_KillSwitchEnabled() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        vm.expectRevert(IGuardianManager.KillSwitchEnabled.selector);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_AlreadyRecovering() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        vm.expectRevert(IGuardianManager.RecoveryInProcess.selector);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_AcceptGuardian_RevertWhen_RecoveryModuleNotInstalled() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

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
