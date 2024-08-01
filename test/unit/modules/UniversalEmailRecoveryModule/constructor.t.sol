// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract UniversalEmailRecoveryManager_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor_RevertWhen_InvalidManager() public {
        address invalidManager = address(0);
        vm.expectRevert(UniversalEmailRecoveryModule.InvalidManager.selector);
        new UniversalEmailRecoveryModule(invalidManager);
    }

    function test_Constructor() public {
        UniversalEmailRecoveryModule emailRecoveryModule =
            new UniversalEmailRecoveryModule(emailRecoveryManagerAddress);

        assertEq(emailRecoveryManagerAddress, emailRecoveryModule.emailRecoveryManager());
    }
}
