// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EnumerableGuardianMap_remove_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Remove_ReturnsFalseWhenRemovingKeysNotInTheSet() public view {}
    function test_Remove_RemovesAddedKeys() public view {}
}
