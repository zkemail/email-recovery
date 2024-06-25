// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "../../../../src/libraries/EnumerableGuardianMap.sol";

contract EnumerableGuardianMap_keys_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function test_Keys_StartsEmpty() public view {
        address[] memory keys = guardiansStorage[accountAddress].keys();
        assertEq(keys.length, 0);
    }

    function test_Keys_ReturnsArrayOfKeys() public {
        bool result;

        for (uint256 i = 1; i <= 3; i++) {
            result = guardiansStorage[accountAddress].set({
                key: vm.addr(i),
                value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
            });
            assertEq(result, true);
        }
        address[] memory keys = guardiansStorage[accountAddress].keys();
        assertEq(keys.length, 3);
        for (uint256 i = 0; i < 3; i++) {
            assertEq(keys[i], vm.addr(i + 1));
        }
    }

    function test_Keys_ReturnMaxArrayOfKeys() public {
        bool result;

        for (uint256 i = 1; i <= EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS; i++) {
            result = guardiansStorage[accountAddress].set({
                key: vm.addr(i),
                value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
            });
            assertEq(result, true);
        }
        address[] memory keys = guardiansStorage[accountAddress].keys();
        assertEq(keys.length, EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS);
        for (uint256 i = 0; i < EnumerableGuardianMap.MAX_NUMBER_OF_GUARDIANS; i++) {
            assertEq(keys[i], vm.addr(i + 1));
        }
    }
}
