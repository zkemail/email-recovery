// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
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
            address(emailRecoveryHandler),
            invalidValidator,
            functionSelector
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
            address(emailRecoveryHandler),
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
            address(emailRecoveryHandler),
            validatorAddress,
            IModule.onUninstall.selector
        );
    }

    function test_Constructor_RevertWhen_UnsafeExecuteSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryModule.InvalidSelector.selector, IERC7579Account.execute.selector
            )
        );
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler),
            validatorAddress,
            IERC7579Account.execute.selector
        );
    }

    function test_Constructor_RevertWhen_UnsafeSetFallbackHandlerSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryModule.InvalidSelector.selector, ISafe.setFallbackHandler.selector
            )
        );
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler),
            validatorAddress,
            ISafe.setFallbackHandler.selector
        );
    }

    function test_Constructor_RevertWhen_UnsafeSetGuardSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryModule.InvalidSelector.selector, ISafe.setGuard.selector
            )
        );
        new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler),
            validatorAddress,
            ISafe.setGuard.selector
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
            address(emailRecoveryHandler),
            validatorAddress,
            bytes4(0)
        );
    }

    function test_Constructor() public {
        EmailRecoveryModule emailRecoveryModule = new EmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler),
            validatorAddress,
            functionSelector
        );

        assertEq(validatorAddress, emailRecoveryModule.validator());
        assertEq(functionSelector, emailRecoveryModule.selector());
    }
}
