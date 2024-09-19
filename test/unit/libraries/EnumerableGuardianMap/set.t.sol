// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "../../../../src/libraries/EnumerableGuardianMap.sol";

/* solhint-disable gas-custom-errors */

contract EnumerableGuardianMap_set_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function test_Set_AddsAKey() public {
        guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        require(
            guardiansStorage[accountAddress1]._values[guardians1[0]].status
                == GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
    }

    function test_Set_AddsSeveralKeys() public {
        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(2)].set({
            key: guardians1[1],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[2])
        });
        assertEq(result, true);
        require(
            guardiansStorage[vm.addr(1)]._values[guardians1[0]].status == GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
        require(
            guardiansStorage[vm.addr(2)]._values[guardians1[1]].status == GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
        require(
            guardiansStorage[vm.addr(3)]._values[guardians1[2]].status == GuardianStatus.NONE,
            "Expected status to be NONE"
        );
    }

    function test_Set_ReturnsFalseWhen_AddingKeysAlreadyInTheSet() public {
        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(1)].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, false);
    }

    function test_Set_UpdatesValuesForKeysAlreadyInTheSet() public {
        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(1)].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.ACCEPTED, guardianWeights[1])
        });
        assertEq(result, false);
        require(
            guardiansStorage[vm.addr(1)]._values[guardians1[0]].status == GuardianStatus.ACCEPTED,
            "Expected status to be ACCEPTED"
        );
    }

    function test_Set_RevertWhen_MaxNumberOfGuardiansReached() public {
        bool result;
        for (uint256 i = 1; i <= 32; i++) {
            result = guardiansStorage[accountAddress1].set({
                key: vm.addr(i),
                value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
            });
            assertEq(result, true);
        }
        vm.expectRevert(EnumerableGuardianMap.MaxNumberOfGuardiansReached.selector);
        guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
    }

    function test_Set_UpdatesValueWhenMaxNumberOfGuardiansReached() public {
        bool result;
        for (uint256 i = 1; i <= 32; i++) {
            result = guardiansStorage[accountAddress1].set({
                key: vm.addr(i),
                value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
            });
            assertEq(result, true);
        }

        bool success = guardiansStorage[accountAddress1].set({
            key: vm.addr(1), // update first guardian added in loop
            value: GuardianStorage(GuardianStatus.ACCEPTED, guardianWeights[0])
        });
        assertEq(success, false);
        require(
            guardiansStorage[accountAddress1]._values[vm.addr(1)].status == GuardianStatus.ACCEPTED,
            "Expected status to be ACCEPTED"
        );
        require(
            guardiansStorage[accountAddress1]._values[vm.addr(1)].weight == guardianWeights[0],
            "Expected weight to be 1"
        );
    }
}
