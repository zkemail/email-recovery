// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_onInstall_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_OnInstall_RevertWhen_InvalidOnInstallData() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        bytes memory emptyData = new bytes(0);
        assertEq(emptyData.length, 0);

        vm.startPrank(accountAddress1);
        vm.expectRevert(UniversalEmailRecoveryModule.InvalidOnInstallData.selector);
        emailRecoveryModule.onInstall(emptyData);
    }

    function test_OnInstall_Succeeds() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(
                validatorAddress,
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });

        bytes4 allowedSelector =
            emailRecoveryModule.exposed_allowedSelectors(validatorAddress, accountAddress1);

        assertEq(allowedSelector, functionSelector);

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress1);
        assertEq(allowedValidators.length, 1);
        assertEq(allowedSelectors.length, 1);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertTrue(isActivated);
    }
}
