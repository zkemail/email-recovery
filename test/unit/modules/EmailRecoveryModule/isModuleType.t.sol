// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

contract EmailRecoveryModule_isModuleType_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_IsModuleType_ReturnsModuleType() public {
        // Uninstall the module to ensure a clean state
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        // Install and initialize the module
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
        });

        // Verify that the module type is correct
        bool isExecutor = emailRecoveryModule.isModuleType(MODULE_TYPE_EXECUTOR);
        assertTrue(isExecutor, "Should be an executor module");

        bool isValidator = emailRecoveryModule.isModuleType(MODULE_TYPE_VALIDATOR);
        assertFalse(isValidator, "Should not be a validator module");
    }
}
