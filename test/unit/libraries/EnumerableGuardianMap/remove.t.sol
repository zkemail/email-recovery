// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "../../../../src/libraries/EnumerableGuardianMap.sol";

/* solhint-disable gas-custom-errors */

contract EnumerableGuardianMap_remove_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function test_Remove_RemovesAddedKeys() public {
        bool result;

        guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        result = guardiansStorage[accountAddress1].remove(guardians1[0]);
        assertEq(result, true);
        require(
            guardiansStorage[accountAddress1]._values[guardians1[0]].status == GuardianStatus.NONE,
            "Expected status to be NONE"
        );
    }

    function test_Remove_ReturnsFalseWhenRemovingKeysNotInTheSet() public {
        bool result;

        result = guardiansStorage[accountAddress1].remove(guardians1[0]);
        assertEq(result, false);
    }

    function test_Remove_AddsAndRemovesMultipleKeys() public {
        bool result;

        // []

        result = guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress1].set({
            key: guardians1[2],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);

        // [1, 3]

        result = guardiansStorage[accountAddress1].remove(guardians1[0]);
        assertEq(result, true);
        result = guardiansStorage[accountAddress1].remove(guardians1[1]);
        assertEq(result, false);

        // [3]

        result = guardiansStorage[accountAddress1].set({
            key: guardians1[1],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);

        // [3,2]

        result = guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress1].remove(guardians1[2]);
        assertEq(result, true);

        // [1,2]

        result = guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, false);
        result = guardiansStorage[accountAddress1].set({
            key: guardians1[1],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, false);

        // [1,2]

        result = guardiansStorage[accountAddress1].set({
            key: guardians1[2],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress1].remove(guardians1[0]);
        assertEq(result, true);

        // [2,3]

        result = guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
        assertEq(result, true);
        result = guardiansStorage[accountAddress1].remove(guardians1[1]);
        assertEq(result, true);

        // [1,3]
        require(
            guardiansStorage[accountAddress1]._values[guardians1[0]].status
                == GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
        require(
            guardiansStorage[accountAddress1]._values[guardians1[1]].status == GuardianStatus.NONE,
            "Expected status to be NONE"
        );
        require(
            guardiansStorage[accountAddress1]._values[guardians1[2]].status
                == GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
    }
}
