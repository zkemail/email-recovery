// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import {UnitBase} from "../../UnitBase.t.sol";
import {EnumerableGuardianMap, GuardianStorage, GuardianStatus} from "../../../../src/libraries/EnumerableGuardianMap.sol";

contract EnumerableGuardianMap_remove_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;
    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian)
        internal guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function test_Remove_RemovesAddedKeys() public {
        bool result;

        guardiansStorage[accountAddress].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        result = guardiansStorage[accountAddress].remove(guardian1);
        assertEq(result, true);
        require(
            guardiansStorage[accountAddress]._values[guardian1].status ==
                GuardianStatus.NONE,
            "Expected status to be NONE"
        );
    }

    function test_Remove_ReturnsFalseWhenRemovingKeysNotInTheSet() public {
        bool result;

        result = guardiansStorage[accountAddress].remove(guardian1);
        assertEq(result, false);
    }

    function test_Remove_AddsAndRemovesMultipleKeys() public {
        bool result;

        // []

        result = guardiansStorage[accountAddress].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress].set({
            key: guardian3,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);

        // [1, 3]

        result = guardiansStorage[accountAddress].remove(guardian1);
        assertEq(result, true);
        result = guardiansStorage[accountAddress].remove(guardian2);
        assertEq(result, false);

        // [3]

        result = guardiansStorage[accountAddress].set({
            key: guardian2,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);

        // [3,2]

        result = guardiansStorage[accountAddress].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress].remove(guardian3);
        assertEq(result, true);

        // [1,2]

        result = guardiansStorage[accountAddress].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, false);
        result = guardiansStorage[accountAddress].set({
            key: guardian2,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, false);

        // [1,2]

        result = guardiansStorage[accountAddress].set({
            key: guardian3,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress].remove(guardian1);
        assertEq(result, true);

        // [2,3]

        result = guardiansStorage[accountAddress].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress].remove(guardian2);
        assertEq(result, true);

        // [1,3]
        require(
            guardiansStorage[accountAddress]._values[guardian1].status ==
                GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
        require(
            guardiansStorage[accountAddress]._values[guardian2].status ==
                GuardianStatus.NONE,
            "Expected status to be NONE"
        );
        require(
            guardiansStorage[accountAddress]._values[guardian3].status ==
                GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
    }
}
