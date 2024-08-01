// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_isAuthorizedToBeRecovered_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_IsAuthorizedToBeRecovered_ReturnsTrueWhenAuthorized() public view { }
    function test_IsAuthorizedToBeRecovered_ReturnsFalseWhenNotAuthorized() public view { }
}
