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

    function test_Constructor_RevertWhen_InvalidManager() public {
        address invalidManager = address(0);
        vm.expectRevert(EmailRecoveryModule.InvalidManager.selector);
        new EmailRecoveryModule(invalidManager, validatorAddress, functionSelector);
    }

    function test_Constructor_RevertWhen_InvalidValidator() public {
        address invalidValidator = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidValidator.selector, invalidValidator)
        );
        new EmailRecoveryModule(emailRecoveryManagerAddress, invalidValidator, functionSelector);
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

    function test_Constructor_RevertWhen_InvalidSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidSelector.selector, bytes4(0))
        );
        new EmailRecoveryModule(emailRecoveryManagerAddress, validatorAddress, bytes4(0));
    }

    function test_Constructor() public {
        EmailRecoveryModule emailRecoveryModule =
            new EmailRecoveryModule(emailRecoveryManagerAddress, validatorAddress, functionSelector);

        assertEq(emailRecoveryManagerAddress, emailRecoveryModule.emailRecoveryManager());
        assertEq(validatorAddress, emailRecoveryModule.validator());
        assertEq(functionSelector, emailRecoveryModule.selector());
    }
}
