// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

contract EmailRecoveryManager_constructor_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_UnsafeOnInstallSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryModule.InvalidSelector.selector, IModule.onInstall.selector
            )
        );
        new EmailRecoveryModule(
            emailRecoveryManagerAddress, validatorAddress, IModule.onInstall.selector
        );
    }

    function test_Constructor_RevertWhen_UnsafeOnUninstallSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryModule.InvalidSelector.selector, IModule.onUninstall.selector
            )
        );
        new EmailRecoveryModule(
            emailRecoveryManagerAddress, validatorAddress, IModule.onUninstall.selector
        );
    }

    function test_Constructor() public {
        EmailRecoveryModule emailRecoveryModule =
            new EmailRecoveryModule(emailRecoveryManagerAddress, validatorAddress, functionSelector);

        assertEq(emailRecoveryManagerAddress, emailRecoveryModule.emailRecoveryManager());
        assertEq(validatorAddress, emailRecoveryModule.validator());
        assertEq(functionSelector, emailRecoveryModule.selector());
    }
}
