// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "src/libraries/EnumerableGuardianMap.sol";

contract GuardianManager_removeAllGuardians_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_RemoveAllGuardians_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_removeAllGuardians(accountAddress1);

        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage1.weight, 0);

        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage2.weight, 0);

        GuardianStorage memory guardianStorage3 =
            emailRecoveryModule.getGuardian(accountAddress1, guardians1[2]);
        assertEq(uint256(guardianStorage3.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage3.weight, 0);
    }
}
