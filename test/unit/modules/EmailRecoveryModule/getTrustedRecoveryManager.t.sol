// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_getTrustedRecoveryManager_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_GetTrustedRecoveryManager_Succeeds() public view { }
}
