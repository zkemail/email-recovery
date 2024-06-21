// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../../UnitBase.t.sol";
import {EnumerableGuardianMap, GuardianStorage, GuardianStatus} from "../../../../src/libraries/EnumerableGuardianMap.sol";

contract EnumerableGuardianMap_set_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;
    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian)
        internal guardiansStorage;

    function setUp() public override {
        super.setUp();
    }

    function test_Set_AddsAKey() public {
        guardiansStorage[accountAddress].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
    }

    function test_Set_AddsSeveralKeys() public {
        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(2)].set({
            key: guardian2,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[2])
        });
        assertEq(result, true);
        require(
            guardiansStorage[vm.addr(1)]._values[guardian1].status ==
                GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
        require(
            guardiansStorage[vm.addr(2)]._values[guardian2].status ==
                GuardianStatus.REQUESTED,
            "Expected status to be REQUESTED"
        );
        require(
            guardiansStorage[vm.addr(3)]._values[guardian3].status ==
                GuardianStatus.NONE,
            "Expected status to be NONE"
        );
    }

    function test_Set_ReturnsFalseWhen_AddingKeysAlreadyInTheSet() public {
        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(1)].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, false);
    }

    function test_Set_UpdatesValuesForKeysAlreadyInTheSet() public {
        bool result;

        result = guardiansStorage[vm.addr(1)].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
        assertEq(result, true);
        result = guardiansStorage[vm.addr(1)].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.ACCEPTED, guardianWeights[1])
        });
        assertEq(result, false);
        require(
            guardiansStorage[vm.addr(1)]._values[guardian1].status ==
                GuardianStatus.ACCEPTED,
            "Expected status to be ACCEPTED"
        );
    }

    function test_Set_RevertWhen_MaxNumberOfGuardiansReached() public {
        bool result;
        // TODO: Can it be acceptable to number 33?
        for (uint256 i = 1; i <= 33; i++) {
            result = guardiansStorage[accountAddress].set({
                key: vm.addr(i),
                value: GuardianStorage(
                    GuardianStatus.REQUESTED,
                    guardianWeights[1]
                )
            });
            assertEq(result, true);
        }
        vm.expectRevert(
            EnumerableGuardianMap.MaxNumberOfGuardiansReached.selector
        );
        guardiansStorage[accountAddress].set({
            key: guardian1,
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[1])
        });
    }
}
