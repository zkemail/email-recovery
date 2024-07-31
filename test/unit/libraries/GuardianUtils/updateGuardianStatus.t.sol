// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

contract GuardianUtils_updateGuardianStatus_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();

        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();
    }

    function test_UpdateGuardianStatus_RevertWhen_StatusIsAlreadyNONE() public {
        GuardianStatus newStatus = GuardianStatus.NONE;

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.StatusCannotBeTheSame.selector, uint256(newStatus)
            )
        );
        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);
    }

    function test_UpdateGuardianStatus_RevertWhen_StatusIsAlreadyREQUESTED() public {
        GuardianStatus newStatus = GuardianStatus.REQUESTED;

        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.StatusCannotBeTheSame.selector, uint256(newStatus)
            )
        );
        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);
    }

    function test_UpdateGuardianStatus_RevertWhen_StatusIsAlreadyACCEPTED() public {
        GuardianStatus newStatus = GuardianStatus.ACCEPTED;

        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        vm.expectRevert(
            abi.encodeWithSelector(
                IGuardianManager.StatusCannotBeTheSame.selector, uint256(newStatus)
            )
        );
        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);
    }

    function test_UpdateGuardianStatus_UpdatesStatusToNONE() public {
        GuardianStatus newStatus = GuardianStatus.NONE;

        emailRecoveryModule.exposed_updateGuardianStatus(
            accountAddress, guardian1, GuardianStatus.REQUESTED
        );

        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(newStatus));
        assertEq(guardianStorage.weight, 0);
    }

    function test_UpdateGuardianStatus_UpdatesStatusToREQUESTED() public {
        GuardianStatus newStatus = GuardianStatus.REQUESTED;

        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(newStatus));
        assertEq(guardianStorage.weight, 0);
    }

    function test_UpdateGuardianStatus_UpdatesStatusToACCEPTED() public {
        GuardianStatus newStatus = GuardianStatus.ACCEPTED;

        vm.expectEmit();
        emit IGuardianManager.GuardianStatusUpdated(accountAddress, guardian1, newStatus);
        emailRecoveryModule.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        GuardianStorage memory guardianStorage =
            emailRecoveryModule.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(newStatus));
        assertEq(guardianStorage.weight, 0);
    }
}
