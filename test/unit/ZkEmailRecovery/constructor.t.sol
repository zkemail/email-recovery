// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";

contract ZkEmailRecovery_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor() public {
        EmailRecoveryManager emailRecoveryManager = new EmailRecoveryManager(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );

        assertEq(address(verifier), emailRecoveryManager.verifier());
        assertEq(address(ecdsaOwnedDkimRegistry), emailRecoveryManager.dkim());
        assertEq(address(emailAuthImpl), emailRecoveryManager.emailAuthImplementation());
    }
}
