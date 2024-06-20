// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";

contract EmailRecoveryManager_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_InvalidSubjectHandler() public {
        address invalidHandler = address(0);
        vm.expectRevert(IEmailRecoveryManager.InvalidSubjectHandler.selector);
        new EmailRecoveryManager(
            address(verifier), address(dkimRegistry), address(emailAuthImpl), invalidHandler
        );
    }

    function test_Constructor() public {
        EmailRecoveryManager emailRecoveryManager = new EmailRecoveryManager(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );

        assertEq(address(verifier), emailRecoveryManager.verifier());
        assertEq(address(dkimRegistry), emailRecoveryManager.dkim());
        assertEq(address(emailAuthImpl), emailRecoveryManager.emailAuthImplementation());
        assertEq(address(emailRecoveryHandler), emailRecoveryManager.subjectHandler());
    }
}
