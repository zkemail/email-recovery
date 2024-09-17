// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_onInstall_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_OnInstall_RevertWhen_InvalidOnInstallData() public {
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        bytes memory emptyData = new bytes(0);
        assertEq(emptyData.length, 0);

        vm.startPrank(accountAddress);
        vm.expectRevert(EmailRecoveryModule.InvalidOnInstallData.selector);
        emailRecoveryModule.onInstall(emptyData);
    }

    function test_OnInstall_RevertWhen_InvalidValidator() public {
        instance.uninstallModule(MODULE_TYPE_VALIDATOR, validatorAddress, "");

        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidValidator.selector, validatorAddress)
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.onInstall(
            abi.encode(isInstalledContext, guardians, guardianWeights, threshold, delay, expiry)
        );
    }

    function test_OnInstall_Succeeds() public {
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians, guardianWeights, threshold, delay, expiry)
        });

        bool isInitialized = emailRecoveryModule.isInitialized(accountAddress);
        assertTrue(isInitialized);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress);
        assertTrue(isActivated);
    }
}
