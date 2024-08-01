// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

contract EmailRecoveryUniversalFactory_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_InvalidVerifier() public {
        address invalidVerifier = address(0);
        vm.expectRevert(EmailRecoveryUniversalFactory.InvalidVerifier.selector);
        new EmailRecoveryUniversalFactory(invalidVerifier, address(emailAuthImpl));
    }

    function test_Constructor_RevertWhen_InvalidEmailAuthImpl() public {
        address invalidEmailAuth = address(0);
        vm.expectRevert(EmailRecoveryUniversalFactory.InvalidEmailAuthImpl.selector);
        new EmailRecoveryUniversalFactory(address(verifier), invalidEmailAuth);
    }

    function test_Constructor() public {
        EmailRecoveryUniversalFactory emailRecoveryFactory =
            new EmailRecoveryUniversalFactory(address(verifier), address(emailAuthImpl));

        assertEq(address(verifier), emailRecoveryFactory.verifier());
        assertEq(address(emailAuthImpl), emailRecoveryFactory.emailAuthImpl());
    }
}
