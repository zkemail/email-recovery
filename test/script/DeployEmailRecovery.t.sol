// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployEmailRecoveryTest } from "test/script/base/BaseDeployEmailRecovery.t.sol";
import { DeployEmailRecoveryScript } from "script/DeployEmailRecovery.s.sol";

contract DeployEmailRecoveryModuleTest is BaseDeployEmailRecoveryTest {
    function setUp() public override {
        super.setUp();
        target = new DeployEmailRecoveryScript();
    }
}
