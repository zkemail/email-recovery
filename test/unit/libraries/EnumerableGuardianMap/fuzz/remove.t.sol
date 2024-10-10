// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "src/libraries/EnumerableGuardianMap.sol";

/* solhint-disable gas-custom-errors */

contract EnumerableGuardianMap_Remove_Fuzz_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function testFuzz_Remove_RemovesAddedKeys(
        address key,
        uint256 guardianStatus,
        uint256 weight
    )
        public
    {
        guardianStatus = bound(guardianStatus, 0, 2);

        guardiansStorage[accountAddress1].set({
            key: key,
            value: GuardianStorage(GuardianStatus(guardianStatus), weight)
        });
        GuardianStorage memory guardian = guardiansStorage[accountAddress1]._values[key];
        assertEq(uint256(guardian.status), guardianStatus);
        assertEq(guardian.weight, weight);

        bool result = guardiansStorage[accountAddress1].remove(key);
        assertTrue(result);

        guardian = guardiansStorage[accountAddress1]._values[key];
        assertEq(uint256(guardian.status), uint256(GuardianStatus.NONE));
        assertEq(guardian.weight, 0);
    }

    function testFuzz_Remove_ReturnsFalseWhenRemovingKeysNotInTheSet(address key) public {
        bool result = guardiansStorage[accountAddress1].remove(key);
        assertFalse(result);
    }

    function testFuzz_Remove_AddsAndRemovesMultipleKeys(
        address key1,
        address key2,
        address key3,
        uint256 guardianStatus1,
        uint256 guardianStatus2,
        uint256 guardianStatus3,
        uint256 weight1,
        uint256 weight2,
        uint256 weight3
    )
        public
    {
        vm.assume(key1 != key2 && key1 != key3 && key2 != key3);
        guardianStatus1 = bound(guardianStatus1, 0, 2);
        guardianStatus2 = bound(guardianStatus2, 0, 2);
        guardianStatus3 = bound(guardianStatus3, 0, 2);
        bool result;

        // []

        result = guardiansStorage[accountAddress1].set({
            key: key1,
            value: GuardianStorage(GuardianStatus(guardianStatus1), weight1)
        });
        assertTrue(result);
        result = guardiansStorage[accountAddress1].set({
            key: key3,
            value: GuardianStorage(GuardianStatus(guardianStatus3), weight3)
        });
        assertTrue(result);

        GuardianStorage memory guardian1 = guardiansStorage[accountAddress1]._values[key1];
        GuardianStorage memory guardian3 = guardiansStorage[accountAddress1]._values[key3];
        assertEq(uint256(guardian1.status), guardianStatus1);
        assertEq(guardian1.weight, weight1);
        assertEq(uint256(guardian3.status), guardianStatus3);
        assertEq(guardian3.weight, weight3);

        // [1, 3]

        result = guardiansStorage[accountAddress1].remove(key1);
        assertTrue(result);
        result = guardiansStorage[accountAddress1].remove(key2);
        assertFalse(result);

        guardian1 = guardiansStorage[accountAddress1]._values[key1];
        assertEq(uint256(guardian1.status), uint256(GuardianStatus.NONE));
        assertEq(guardian1.weight, 0);

        // [3]

        result = guardiansStorage[accountAddress1].set({
            key: key2,
            value: GuardianStorage(GuardianStatus(guardianStatus2), weight2)
        });
        assertTrue(result);

        GuardianStorage memory guardian2 = guardiansStorage[accountAddress1]._values[key2];
        assertEq(uint256(guardian2.status), guardianStatus2);
        assertEq(guardian2.weight, weight2);

        // [3,2]

        result = guardiansStorage[accountAddress1].set({
            key: key1,
            value: GuardianStorage(GuardianStatus(guardianStatus3), weight3)
        });
        assertTrue(result);
        result = guardiansStorage[accountAddress1].remove(key3);
        assertTrue(result);

        guardian1 = guardiansStorage[accountAddress1]._values[key1];
        guardian3 = guardiansStorage[accountAddress1]._values[key3];
        assertEq(uint256(guardian1.status), guardianStatus3);
        assertEq(guardian1.weight, weight3);
        assertEq(uint256(guardian3.status), uint256(GuardianStatus.NONE));
        assertEq(guardian3.weight, 0);

        // [1,2]

        result = guardiansStorage[accountAddress1].set({
            key: key1,
            value: GuardianStorage(GuardianStatus(guardianStatus3), weight3)
        });
        assertFalse(result);
        result = guardiansStorage[accountAddress1].set({
            key: key2,
            value: GuardianStorage(GuardianStatus(guardianStatus2), weight2)
        });
        assertFalse(result);

        guardian1 = guardiansStorage[accountAddress1]._values[key1];
        guardian2 = guardiansStorage[accountAddress1]._values[key2];
        assertEq(uint256(guardian1.status), guardianStatus3);
        assertEq(guardian1.weight, weight3);
        assertEq(uint256(guardian2.status), guardianStatus2);
        assertEq(guardian2.weight, weight2);

        // [1,2]

        result = guardiansStorage[accountAddress1].set({
            key: key3,
            value: GuardianStorage(GuardianStatus(guardianStatus2), weight2)
        });
        assertTrue(result);
        result = guardiansStorage[accountAddress1].remove(key1);
        assertTrue(result);

        guardian3 = guardiansStorage[accountAddress1]._values[key3];
        guardian1 = guardiansStorage[accountAddress1]._values[key1];
        assertEq(uint256(guardian3.status), guardianStatus2);
        assertEq(guardian3.weight, weight2);
        assertEq(uint256(guardian1.status), uint256(GuardianStatus.NONE));
        assertEq(guardian1.weight, 0);

        // [2,3]

        result = guardiansStorage[accountAddress1].set({
            key: key1,
            value: GuardianStorage(GuardianStatus(guardianStatus2), weight2)
        });
        assertTrue(result);
        result = guardiansStorage[accountAddress1].remove(key2);
        assertTrue(result);

        guardian1 = guardiansStorage[accountAddress1]._values[key1];
        guardian2 = guardiansStorage[accountAddress1]._values[key2];
        guardian3 = guardiansStorage[accountAddress1]._values[key3];
        assertEq(uint256(guardian1.status), guardianStatus2);
        assertEq(guardian1.weight, weight2);
        assertEq(uint256(guardian2.status), uint256(GuardianStatus.NONE));
        assertEq(guardian2.weight, 0);
        assertEq(uint256(guardian3.status), guardianStatus2);
        assertEq(guardian3.weight, weight2);

        // [1,3]
    }
}
