// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_isInitialized_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_IsInitialized_ReturnsTrueWhenInitialized() public view { }
    function test_IsInitialized_ReturnsFalseWhenUninitialized() public view { }
}
