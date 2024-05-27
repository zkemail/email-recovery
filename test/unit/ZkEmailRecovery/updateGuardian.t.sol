// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

// external updateGuardian()
contract ZkEmailRecovery_updateGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_MsgSenderNotConfigured() public {}
    function test_RevertWhen_AlreadyRecovering() public {}
}

// internal _updateGuardian()
contract ZkEmailRecovery__updateGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_InvalidAccountAddress() public {}
    function test_RevertWhen_InvalidGuardianAddress() public {}
    function test_RevertWhen_GuardianStatusIsTheSame() public {}
    function test_RevertWhen_InvalidGuardianWeight() public {}
    function test_UpdateGuardian_Succeeds() public {}
}
