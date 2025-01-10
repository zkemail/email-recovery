// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

contract EmailRecoveryUniversalFactory_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_InvalidVerifier() public {
        address invalidVerifier = address(0);
        vm.expectRevert(EmailRecoveryUniversalFactory.InvalidVerifier.selector);
        new EmailRecoveryUniversalFactory(invalidVerifier, address(emailAuthImpl), address(eoaVerifier), address(eoaAuthImpl));
    }

    function test_Constructor_RevertWhen_InvalidEmailAuthImpl() public {
        address invalidEmailAuth = address(0);
        vm.expectRevert(EmailRecoveryUniversalFactory.InvalidEmailAuthImpl.selector);
        new EmailRecoveryUniversalFactory(address(verifier), invalidEmailAuth, address(eoaVerifier), address(eoaAuthImpl));
    }

    function test_Constructor() public {
        EmailRecoveryUniversalFactory emailRecoveryFactory =
            new EmailRecoveryUniversalFactory(address(verifier), address(emailAuthImpl), address(eoaVerifier), address(eoaAuthImpl));

        assertEq(address(verifier), emailRecoveryFactory.verifier());
        assertEq(address(emailAuthImpl), emailRecoveryFactory.emailAuthImpl());
    }
}
