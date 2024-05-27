// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_completeRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_NotEnoughApprovals() public {}
    function test_RevertWhen_DelayNotPassed() public {}
    function test_RevertWhen_RecoveryRequestExpired() public {}
    function test_CompleteRecovery_Succeeds() public {}
}
