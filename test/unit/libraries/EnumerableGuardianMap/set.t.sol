// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EnumerableGuardianMap_set_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Set_ReturnsFalseWhen_AddingKeysAlreadyInTheSet() public view { }
    function test_Set_UpdatesValuesForKeysAlreadyInTheSet() public view { }
    function test_Set_RevertWhen_MaxNumberOfGuardiansReached() public view { }
    function test_Set_AddsAKey() public view { }
    function test_Set_AddsSeveralKeys() public view { }
}
