// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { SentinelListHelper } from "sentinellist/SentinelListHelper.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_onUninstall_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;
    using SentinelListHelper for address[];

    function setUp() public override {
        super.setUp();
    }

    function test_OnUninstall_Succeeds() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        bool isInitialized = emailRecoveryModule.isInitialized(accountAddress);
        assertFalse(isInitialized);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertFalse(isActivated);
    }
}
