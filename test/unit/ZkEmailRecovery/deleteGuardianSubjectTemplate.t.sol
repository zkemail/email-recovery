// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_deleteGuardianSubjectTemplate_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RevertWhen_UnauthorizedAccountForGuardian() public {}
    function test_RevertWhen_RecoveryInProcess() public {}
    function test_DeleteGuardianSubjectTemplate_Succeeds() public {}
}
