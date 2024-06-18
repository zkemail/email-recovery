// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoverySubjectHandler_getPreviousOwnerInLinkedList_Test is SafeUnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_GetPreviousOwnerInLinkedList_RevertWhen_InvalidOldOwner() public view { }
    function test_GetPreviousOwnerInLinkedList_RevertWhen_OldOwnerIsSentinel() public view { }
    function test_GetPreviousOwnerInLinkedList_RevertWhen_OldOwnerIsZeroAddress() public view { }
    function test_GetPreviousOwnerInLinkedList_Succeeds() public view { }
}
