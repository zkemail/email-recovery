// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract EmailRecoveryManager_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_InvalidVerifier() public {
        address invalidVerifier = address(0);
        address invalidEoaVerifier = address(0);
        vm.expectRevert(IEmailRecoveryManager.InvalidVerifier.selector);
        new UniversalEmailRecoveryModule(
            invalidVerifier,
            invalidEoaVerifier,
            address(dkimRegistry),
            address(emailAuthImpl),
            address(eoaAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer
        );
    }

    function test_Constructor_RevertWhen_InvalidDkimRegistry() public {
        address invalidDkim = address(0);
        vm.expectRevert(IEmailRecoveryManager.InvalidDkimRegistry.selector);
        new UniversalEmailRecoveryModule(
            address(verifier),
            address(eoaVerifier),
            invalidDkim,
            address(emailAuthImpl),
            address(eoaAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer
        );
    }

    function test_Constructor_RevertWhen_InvalidEmailAuthImpl() public {
        address invalidEmailAuth = address(0);
        address invalidEoaAuth = address(0);
        vm.expectRevert(IEmailRecoveryManager.InvalidEmailAuthImpl.selector);
        new UniversalEmailRecoveryModule(
            address(verifier),
            address(eoaVerifier),
            address(dkimRegistry),
            invalidEmailAuth,
            invalidEoaAuth,
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer
        );
    }

    function test_Constructor_RevertWhen_InvalidCommandHandler() public {
        address invalidHandler = address(0);
        vm.expectRevert(IEmailRecoveryManager.InvalidCommandHandler.selector);
        new UniversalEmailRecoveryModule(
            address(verifier),
            address(eoaVerifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(eoaAuthImpl),
            invalidHandler,
            minimumDelay,
            killSwitchAuthorizer
        );
    }

    function test_Constructor() public {
        UniversalEmailRecoveryModule emailRecoveryModule = new UniversalEmailRecoveryModule(
            address(verifier),
            address(eoaVerifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(eoaAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer
        );

        assertEq(address(verifier), emailRecoveryModule.verifier());
        assertEq(address(dkimRegistry), emailRecoveryModule.dkim());
        assertEq(address(emailAuthImpl), emailRecoveryModule.emailAuthImplementation());
        assertEq(commandHandlerAddress, emailRecoveryModule.commandHandler());
        assertEq(minimumDelay, emailRecoveryModule.minimumDelay());
        assertEq(killSwitchAuthorizer, emailRecoveryModule.owner());
    }
}
