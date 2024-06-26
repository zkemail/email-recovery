// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract GuardianUtils_getGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_GetGuardian_Succeeds() public { }
}
