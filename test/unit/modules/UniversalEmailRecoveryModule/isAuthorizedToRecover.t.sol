// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_isAuthorizedToRecover_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_IsAuthorizedToRecover_ReturnsTrueWhenAuthorized() public view { }
    function test_IsAuthorizedToRecover_ReturnsFalseWhenNotAuthorized() public view { }
}
