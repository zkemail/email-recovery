// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_validateRecoveryConfig_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_DelayLessThanExpiry() public {}
    function test_RevertWhen_RecoveryWindowTooShort() public {}
    function test_ValidateRecoveryConfig_Succeeds() public {}
}
