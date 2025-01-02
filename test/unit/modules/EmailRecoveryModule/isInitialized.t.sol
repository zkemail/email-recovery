// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

contract EmailRecoveryModule_isInitialized_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_IsInitialized_ReturnsTrueWhenInitialized() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        // Install and initialize the module
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
        });

        // Verify that the module is initialized
        bool isInitialized = emailRecoveryModule.isInitialized(accountAddress1);
        assertTrue(isInitialized);
    }

    function test_IsInitialized_ReturnsFalseWhenUninitialized() public {
        // Uninstall the module to make it uninitialized
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        // Verify that the module is uninitialized
        bool isInitialized = emailRecoveryModule.isInitialized(accountAddress1);
        assertFalse(isInitialized);
    }
}
