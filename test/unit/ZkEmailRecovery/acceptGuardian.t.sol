// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_acceptGuardian_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_AlreadyRecovering() public {}
    function test_RevertWhen_InvalidGuardianAddress() public {}
    function test_RevertWhen_InvalidTemplateIndex() public {}
    function test_RevertWhen_InvalidSubjectParams() public {}
    function test_RevertWhen_InvalidGuardianStatus() public {}
    function test_AcceptGuardian_Succeeds() public {}
}
