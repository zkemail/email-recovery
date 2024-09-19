// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "../../../../src/libraries/EnumerableGuardianMap.sol";

/* solhint-disable gas-custom-errors */

contract EnumerableGuardianMap_get_Test is UnitBase {
    using EnumerableGuardianMap for EnumerableGuardianMap.AddressToGuardianMap;

    mapping(address account => EnumerableGuardianMap.AddressToGuardianMap guardian) internal
        guardiansStorage;

    function setUp() public override {
        super.setUp();
        guardiansStorage[accountAddress1].set({
            key: guardians1[0],
            value: GuardianStorage(GuardianStatus.REQUESTED, guardianWeights[0])
        });
    }

    function test_Get_GetsExistingValue() public view {
        GuardianStorage memory result = guardiansStorage[accountAddress1].get(guardians1[0]);
        require(result.status == GuardianStatus.REQUESTED, "Expected status to be REQUESTED");
        require(result.weight == guardianWeights[0], "Expected weight to be 1");
    }

    function test_Get_GetsNonExistentValue() public view {
        // It will returns the default value
        GuardianStorage memory result = guardiansStorage[accountAddress1].get(guardians1[1]);
        require(result.status == GuardianStatus.NONE, "Expected status to be NONE");
        require(result.weight == 0, "Expected weight to be 0");
    }
}
