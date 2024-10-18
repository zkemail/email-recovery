// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeNativeIntegrationBase } from
    "../../../../integration/SafeRecovery/SafeNativeIntegrationBase.t.sol";
import { SafeRecoveryCommandHandlerHarness } from "../../../SafeRecoveryCommandHandlerHarness.sol";

interface ISafe {
    function addOwnerWithThreshold(address owner, uint256 _threshold) external;
    function getOwners() external view returns (address[] memory);
    function isOwner(address owner) external view returns (bool);
}

contract SafeRecoveryCommandHandler_getPreviousOwnerInLinkedList_Fuzz_Test is
    SafeNativeIntegrationBase
{
    address internal constant SENTINEL_OWNERS = address(0x1);

    SafeRecoveryCommandHandlerHarness public safeRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        safeRecoveryCommandHandler = new SafeRecoveryCommandHandlerHarness();
    }

    function testFuzz_GetPreviousOwnerInLinkedList_Succeeds(address[] memory owners) public {
        skipIfNotSafeAccountType();

        vm.startPrank(accountAddress1);
        for (uint256 i = 0; i < owners.length; i++) {
            if (ISafe(accountAddress1).isOwner(owners[i])) {
                break;
            }
            vm.assume(owners[i] != address(0));
            vm.assume(owners[i] != address(1));
            vm.assume(owners[i] != accountAddress1);
            ISafe(accountAddress1).addOwnerWithThreshold(owners[i], 1);
        }
        vm.stopPrank();

        address[] memory ownersArr = ISafe(accountAddress1).getOwners();

        address expectedPreviousOwner;
        for (uint256 i = 1; i < ownersArr.length; i++) {
            address previousOwner = safeRecoveryCommandHandler.exposed_getPreviousOwnerInLinkedList(
                accountAddress1, ownersArr[i]
            );
            if (i == 0) {
                assertEq(previousOwner, SENTINEL_OWNERS);
            }

            uint256 prevOwnerIndex = i - 1;
            expectedPreviousOwner = ownersArr[prevOwnerIndex];

            assertEq(expectedPreviousOwner, previousOwner);
        }
    }
}
