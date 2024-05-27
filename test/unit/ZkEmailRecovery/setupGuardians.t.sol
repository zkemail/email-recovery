// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_setupGuardians_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_SetupAlreadyCalled() public {}
    function test_RevertWhen_ThresholdExceedsGuardianCount() public {}
    function test_RevertWhen_ThresholdIsZero() public {}
    function test_RevertWhen_InvalidGuardianAddress() public {}
    function test_RevertWhen_InvalidGuardianWeight() public {}
    function test_RevertWhen_AddressAlreadyRequested() public {}
    function test_RevertWhen_AddressAlreadyGuardian() public {}
    function test_SetupGuardians_Succeeds() public {}
}
