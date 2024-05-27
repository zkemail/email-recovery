// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_addGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_MsgSenderNotConfigured() public {}
    function test_RevertWhen_AlreadyRecovering() public {}
    function test_RevertWhen_InvalidGuardianAddress() public {}
    function test_RevertWhen_AddressAlreadyRequested() public {}
    function test_RevertWhen_AddressAlreadyGuardian() public {}
    function test_RevertWhen_InvalidGuardianWeight() public {}

    function test_AddGuardian_SameThreshold() public {}
    function test_AddGuardian_DifferentThreshold() public {}
}
