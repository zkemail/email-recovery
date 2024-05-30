// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract ZkEmailRecovery_deployRouterForAccount_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_DeployRouterForAccount_RouterAlreadyDeployed() public {
        address expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);
        assertEq(expectedRouter.code.length, 0);

        // Deploy router
        address router = zkEmailRecovery.exposed_deployRouterForAccount(accountAddress);
        expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);
        assertGt(expectedRouter.code.length, 0);
        assertEq(router, expectedRouter);

        // Try to deploy agin
        router = zkEmailRecovery.exposed_deployRouterForAccount(accountAddress);
        expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);
        assertGt(expectedRouter.code.length, 0);
        assertEq(router, expectedRouter);
    }

    function test_DeployRouterForAccount_DeployNewRouter() public {
        address expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);
        assertEq(expectedRouter.code.length, 0);

        // Deploy router
        address router = zkEmailRecovery.exposed_deployRouterForAccount(accountAddress);
        expectedRouter = zkEmailRecovery.getRouterForAccount(accountAddress);
        assertGt(expectedRouter.code.length, 0);
        assertEq(router, expectedRouter);
    }
}
