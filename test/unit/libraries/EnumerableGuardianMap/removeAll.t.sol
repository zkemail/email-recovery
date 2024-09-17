// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "../../../../src/libraries/EnumerableGuardianMap.sol";

contract EnumerableGuardianMap_removeAll_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function test_RemoveAll_Succeeds() public {
        bool result;

        for (uint256 i = 1; i <= 3; i++) {
            result = guardiansStorage[accountAddress].set({
                key: vm.addr(i),
                value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
            });
            assertEq(result, true);
        }
        address[] memory addresses = new address[](3);
        addresses[0] = vm.addr(1);
        addresses[1] = vm.addr(2);
        addresses[2] = vm.addr(3);
        guardiansStorage[accountAddress].removeAll(addresses);
        for (uint256 i = 1; i <= 3; i++) {
            require(
                guardiansStorage[accountAddress]._values[vm.addr(i)].status == GuardianStatus.NONE,
                "Expected status to be NONE"
            );
        }
    }

    function test_RemoveAll_RemovesMaxNumberOfValues() public {
        bool result;

        for (uint256 i = 1; i <= EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS; i++) {
            result = guardiansStorage[accountAddress].set({
                key: vm.addr(i),
                value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
            });
            assertEq(result, true);
        }

        address[] memory addresses = new address[](EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS);
        for (uint256 i = 0; i < EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS; i++) {
            addresses[i] = vm.addr(i + 1);
        }
        guardiansStorage[accountAddress].removeAll(addresses);
        for (uint256 i = 1; i <= EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS; i++) {
            require(
                guardiansStorage[accountAddress]._values[vm.addr(i)].status == GuardianStatus.NONE,
                "Expected status to be NONE"
            );
        }
    }

    function test_RemoveAll_RevertWhen_TooManyValuesToRemove() public {
        address[] memory addresses =
            new address[](EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS + 1);

        for (uint256 i = 0; i < EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS + 1; i++) {
            addresses[i] = vm.addr(i + 1);
        }
        vm.expectRevert(EnumerableGuardianMap.TooManyValuesToRemove.selector);
        guardiansStorage[accountAddress].removeAll(addresses);
    }
}
