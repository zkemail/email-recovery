// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoveryCommandHandler_getPreviousOwnerInLinkedList_Test is SafeUnitBase {
    address internal constant SENTINEL_OWNERS = address(0x1);

    function setUp() public override {
        super.setUp();
    }

    function test_GetPreviousOwnerInLinkedList_InvalidOwner_ReturnsSentinel() public {
        skipIfNotSafeAccountType();
        address invalidOwner = address(0);

        address previousOwner = safeRecoveryCommandHandler.exposed_getPreviousOwnerInLinkedList(
            accountAddress1, invalidOwner
        );

        assertEq(previousOwner, SENTINEL_OWNERS);
    }

    function test_GetPreviousOwnerInLinkedList_OwnerIsSentinel_ReturnsSentinel() public {
        skipIfNotSafeAccountType();
        address invalidOwner = SENTINEL_OWNERS;

        address previousOwner = safeRecoveryCommandHandler.exposed_getPreviousOwnerInLinkedList(
            accountAddress1, invalidOwner
        );

        assertEq(previousOwner, SENTINEL_OWNERS);
    }

    function test_GetPreviousOwnerInLinkedList_RevertWhen_InvalidAccount() public {
        skipIfNotSafeAccountType();
        address invalidAccount = address(0);

        vm.expectRevert();
        safeRecoveryCommandHandler.exposed_getPreviousOwnerInLinkedList(invalidAccount, owner1);
    }

    function test_GetPreviousOwnerInLinkedList_Succeeds() public {
        skipIfNotSafeAccountType();
        address expectedPreviousOwner = address(1);
        address previousOwner =
            safeRecoveryCommandHandler.exposed_getPreviousOwnerInLinkedList(accountAddress1, owner1);

        assertEq(expectedPreviousOwner, previousOwner);
    }

    function test_GetPreviousOwnerInLinkedList_SucceedsWithMultipleAccounts() public {
        skipIfNotSafeAccountType();
        address expectedPreviousOwner = address(1);
        address previousOwner =
            safeRecoveryCommandHandler.exposed_getPreviousOwnerInLinkedList(accountAddress1, owner1);

        assertEq(expectedPreviousOwner, previousOwner);
        previousOwner =
            safeRecoveryCommandHandler.exposed_getPreviousOwnerInLinkedList(accountAddress1, owner2);
        assertEq(expectedPreviousOwner, previousOwner);
    }
}
