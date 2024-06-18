// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoveryModule_allowValidatorRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_AllowValidatorRecovery_RevertWhen_InvalidValidator() public view { }
    function test_AllowValidatorRecovery_SucceedsWhenAlreadyInitialized() public view { }
    function test_AllowValidatorRecovery_SucceedsWhenInitializing() public view { }
}
