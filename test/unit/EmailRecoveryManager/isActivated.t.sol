// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_isActivated_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_isActivated_ReturnsTrueWhenModuleIsInstalled() public view {
        bool isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertTrue(isActivated);
    }

    function test_isActivated_ReturnsFalseWhenModuleIsInstalled() public {
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        bool isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertFalse(isActivated);
    }
}
