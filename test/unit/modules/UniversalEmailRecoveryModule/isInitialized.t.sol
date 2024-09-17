// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_isInitialized_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_IsInitialized_ReturnsTrueWhenInitialized() public view { }
    function test_IsInitialized_ReturnsFalseWhenUninitialized() public view { }
}
