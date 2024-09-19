// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_isActivated_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_isActivated_ReturnsTrueWhenModuleIsInstalled() public view {
        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertTrue(isActivated);
    }

    function test_isActivated_ReturnsFalseWhenModuleIsInstalled() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertFalse(isActivated);
    }
}
