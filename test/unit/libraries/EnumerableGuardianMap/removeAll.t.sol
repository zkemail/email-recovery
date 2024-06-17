// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EnumerableGuardianMap_removeAll_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RemoveAll_RevertWhen_TooManyValuesToRemove() public view { }
    function test_RemoveAll_Succeeds() public view { }
    function test_RemoveAll_RemovesMaxNumberOfValues() public view { }
}
