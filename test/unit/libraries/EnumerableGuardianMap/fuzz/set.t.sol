// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "src/libraries/EnumerableGuardianMap.sol";

/* solhint-disable gas-custom-errors */

contract EnumerableGuardianMap_Set_Fuzz_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function testFuzz_Set_AddsAKey(address key, uint256 guardianStatus, uint256 weight) public {
        guardianStatus = bound(guardianStatus, 0, 2);

        bool result = guardiansStorage[accountAddress1].set({
            key: key,
            value: GuardianStorage(GuardianStatus(guardianStatus), weight)
        });

        GuardianStorage memory guardian = guardiansStorage[accountAddress1]._values[key];

        assertTrue(result);
        assertEq(uint256(guardian.status), guardianStatus);
        assertEq(guardian.weight, weight);
    }

    function testFuzz_Set_AddsSeveralKeys(
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
        guardianStatus1 = bound(guardianStatus1, 0, 2);
        guardianStatus2 = bound(guardianStatus2, 0, 2);
        guardianStatus3 = bound(guardianStatus3, 0, 2);

        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: key1,
            value: GuardianStorage(GuardianStatus(guardianStatus1), weight1)
        });
        assertEq(result, true);

        result = guardiansStorage[vm.addr(2)].set({
            key: key2,
            value: GuardianStorage(GuardianStatus(guardianStatus2), weight2)
        });
        assertEq(result, true);

        result = guardiansStorage[vm.addr(3)].set({
            key: key3,
            value: GuardianStorage(GuardianStatus(guardianStatus3), weight3)
        });
        assertEq(result, true);

        GuardianStorage memory guardian1 = guardiansStorage[vm.addr(1)]._values[key1];
        assertEq(uint256(guardian1.status), guardianStatus1);
        assertEq(guardian1.weight, weight1);

        GuardianStorage memory guardian2 = guardiansStorage[vm.addr(2)]._values[key2];
        assertEq(uint256(guardian2.status), guardianStatus2);
        assertEq(guardian2.weight, weight2);

        GuardianStorage memory guardian3 = guardiansStorage[vm.addr(3)]._values[key3];
        assertEq(uint256(guardian3.status), guardianStatus3);
        assertEq(guardian3.weight, weight3);
    }

    function testFuzz_Set_ReturnsFalseWhen_AddingKeysAlreadyInTheSet(
        address key,
        uint256 guardianStatus,
        uint256 weight
    )
        public
    {
        guardianStatus = bound(guardianStatus, 0, 2);

        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: key,
            value: GuardianStorage(GuardianStatus(guardianStatus), weight)
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(1)].set({
            key: key,
            value: GuardianStorage(GuardianStatus(guardianStatus), weight)
        });
        assertEq(result, false);
    }

    function testFuzz_Set_UpdatesValuesForKeysAlreadyInTheSet(address key, uint256 weight) public {
        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: key,
            value: GuardianStorage(GuardianStatus.REQUESTED, weight)
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(1)].set({
            key: key,
            value: GuardianStorage(GuardianStatus.ACCEPTED, weight)
        });
        assertEq(result, false);

        GuardianStorage memory guardian = guardiansStorage[vm.addr(1)]._values[key];
        assertEq(uint256(guardian.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardian.weight, weight);
    }
}
