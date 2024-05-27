// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_deployRouterForAccount_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_RouterAlreadyDeployed() public {}
    function test_DeployRouterForAccount_Succeeds() public {}
}
