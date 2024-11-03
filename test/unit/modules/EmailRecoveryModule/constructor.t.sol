// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe } from "src/interfaces/ISafe.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

contract EmailRecoveryModule_constructor_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_InvalidValidator() public {
        address invalidValidator = address(0);
        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidValidator.selector, invalidValidator)
        );
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            invalidValidator,
            functionSelector
        );
    }

    function test_Constructor_When_SafeAddOwnerSelector() public {
        skipIfNotSafeAccountType();
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            ISafe.addOwnerWithThreshold.selector
        );
    }

    function test_Constructor_When_SafeRemoveOwnerSelector() public {
        skipIfNotSafeAccountType();
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            ISafe.removeOwner.selector
        );
    }

    function test_Constructor_When_SafeSwapOwnerSelector() public {
        skipIfNotSafeAccountType();
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            ISafe.swapOwner.selector
        );
    }

    function test_Constructor_When_SafeChangeThresholdSelector() public {
        skipIfNotSafeAccountType();
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            ISafe.changeThreshold.selector
        );
    }

    function test_Constructor_RevertWhen_UnsafeOnInstallSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryModule.InvalidSelector.selector, IModule.onInstall.selector
            )
        );
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            IModule.onInstall.selector
        );
    }

    function test_Constructor_RevertWhen_UnsafeOnUninstallSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryModule.InvalidSelector.selector, IModule.onUninstall.selector
            )
        );
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            IModule.onUninstall.selector
        );
    }

    function test_Constructor_RevertWhen_InvalidSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidSelector.selector, bytes4(0))
        );
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            bytes4(0)
        );
    }

    function test_Constructor() public {
        EmailRecoveryModule emailRecoveryModule = new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            functionSelector
        );

        assertEq(validatorAddress, emailRecoveryModule.validator());
        assertEq(functionSelector, emailRecoveryModule.selector());
    }
}
