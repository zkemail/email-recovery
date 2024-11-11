// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

contract UniversalEmailRecoveryModule_isModuleType_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_IsModuleType_ReturnsModuleType() public view {
        // Verify that the module type is correct
        bool isExecutor = emailRecoveryModule.isModuleType(MODULE_TYPE_EXECUTOR);
        assertTrue(isExecutor, "Should be an executor module");

        bool isValidator = emailRecoveryModule.isModuleType(MODULE_TYPE_VALIDATOR);
        assertFalse(isValidator, "Should not be a validator module");
    }
}
