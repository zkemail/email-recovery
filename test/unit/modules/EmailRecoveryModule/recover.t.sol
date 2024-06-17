// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryModule_recover_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RevertWhen_NotTrustedRecoveryContract() public view { }
    function test_Recover_RevertWhen_InvalidSubjectParams() public view { }
    function test_Recover_RevertWhen_InvalidOldOwner() public view { }
    function test_Recover_RevertWhen_InvalidNewOwner() public view { }
    function test_Recover_Succeeds() public view { }
}
