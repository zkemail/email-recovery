// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployEmailRecoveryTest } from "./base/BaseDeployEmailRecovery.t.sol";
import { DeployEmailRecoveryScript } from "../DeployEmailRecovery.s.sol";

contract DeployEmailRecoveryModuleTest is BaseDeployEmailRecoveryTest {
    function setUp() public override {
        super.setUp();
        target = new DeployEmailRecoveryScript();
    }
}
