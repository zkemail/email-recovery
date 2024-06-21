// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";

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

        vm.expectRevert(GuardianUtils.StatusCannotBeTheSame.selector);
        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);
    }

    function test_UpdateGuardianStatus_RevertWhen_StatusIsAlreadyREQUESTED() public {
        GuardianStatus newStatus = GuardianStatus.REQUESTED;

        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        vm.expectRevert(GuardianUtils.StatusCannotBeTheSame.selector);
        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);
    }

    function test_UpdateGuardianStatus_RevertWhen_StatusIsAlreadyACCEPTED() public {
        GuardianStatus newStatus = GuardianStatus.ACCEPTED;

        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        vm.expectRevert(GuardianUtils.StatusCannotBeTheSame.selector);
        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);
    }

    function test_UpdateGuardianStatus_UpdatesStatusToNONE() public {
        GuardianStatus newStatus = GuardianStatus.NONE;

        emailRecoveryManager.exposed_updateGuardianStatus(
            accountAddress, guardian1, GuardianStatus.REQUESTED
        );

        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        GuardianStorage memory guardianStorage =
            emailRecoveryManager.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(newStatus));
        assertEq(guardianStorage.weight, 0);
    }

    function test_UpdateGuardianStatus_UpdatesStatusToREQUESTED() public {
        GuardianStatus newStatus = GuardianStatus.REQUESTED;

        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        GuardianStorage memory guardianStorage =
            emailRecoveryManager.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(newStatus));
        assertEq(guardianStorage.weight, 0);
    }

    function test_UpdateGuardianStatus_UpdatesStatusToACCEPTED() public {
        GuardianStatus newStatus = GuardianStatus.ACCEPTED;

        emailRecoveryManager.exposed_updateGuardianStatus(accountAddress, guardian1, newStatus);

        GuardianStorage memory guardianStorage =
            emailRecoveryManager.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage.status), uint256(newStatus));
        assertEq(guardianStorage.weight, 0);
    }
}
