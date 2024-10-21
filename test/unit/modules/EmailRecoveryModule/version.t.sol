// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_version_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Version_ReturnsVersion() public view { }
}
