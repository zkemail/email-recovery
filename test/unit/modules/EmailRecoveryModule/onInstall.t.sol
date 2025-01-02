// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_onInstall_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_OnInstall_RevertWhen_InvalidOnInstallData() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        bytes memory emptyData = new bytes(0);
        assertEq(emptyData.length, 0);

        vm.startPrank(accountAddress1);
        vm.expectRevert(EmailRecoveryModule.InvalidOnInstallData.selector);
        emailRecoveryModule.onInstall(emptyData);
    }

    function test_OnInstall_RevertWhen_InvalidValidator() public {
        instance1.uninstallModule(MODULE_TYPE_VALIDATOR, validatorAddress, "");

        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidValidator.selector, validatorAddress)
        );
        vm.startPrank(accountAddress1);
        emailRecoveryModule.onInstall(
            abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
        );
    }

    function test_OnInstall_Succeeds() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
        });

        bool isInitialized = emailRecoveryModule.isInitialized(accountAddress1);
        assertTrue(isInitialized);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertTrue(isActivated);
    }
}
