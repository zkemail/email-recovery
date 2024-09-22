// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";

contract EmailRecoveryFactory_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_InvalidVerifier() public {
        address invalidVerifier = address(0);
        vm.expectRevert(EmailRecoveryFactory.InvalidVerifier.selector);
        new EmailRecoveryFactory(invalidVerifier, address(emailAuthImpl));
    }

    function test_Constructor_RevertWhen_InvalidEmailAuthImpl() public {
        address invalidEmailAuth = address(0);
        vm.expectRevert(EmailRecoveryFactory.InvalidEmailAuthImpl.selector);
        new EmailRecoveryFactory(address(verifier), invalidEmailAuth);
    }

    function test_Constructor() public {
        EmailRecoveryFactory emailRecoveryFactory =
            new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));

        assertEq(address(verifier), emailRecoveryFactory.verifier());
        assertEq(address(emailAuthImpl), emailRecoveryFactory.emailAuthImpl());
    }
}
