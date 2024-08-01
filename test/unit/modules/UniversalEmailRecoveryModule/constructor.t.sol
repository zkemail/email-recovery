// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract UniversalEmailRecoveryModule_constructor_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Constructor() public {
        UniversalEmailRecoveryModule emailRecoveryModule = new UniversalEmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
    }
}
