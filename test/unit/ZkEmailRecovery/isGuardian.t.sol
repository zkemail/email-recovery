// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_isGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ReturnsFalseWhen_AccountIsNotGuardian() public {}
    function test_ReturnsTrueWhen_AccountIsGuardian() public {}
}
