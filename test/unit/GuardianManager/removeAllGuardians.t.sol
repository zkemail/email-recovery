// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
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
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        acceptGuardian(accountSalt3);

        emailRecoveryModule.exposed_removeAllGuardians(accountAddress);

        GuardianStorage memory guardianStorage1 =
            emailRecoveryModule.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage1.weight, 0);

        GuardianStorage memory guardianStorage2 =
            emailRecoveryModule.getGuardian(accountAddress, guardian2);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage2.weight, 0);

        GuardianStorage memory guardianStorage3 =
            emailRecoveryModule.getGuardian(accountAddress, guardian3);
        assertEq(uint256(guardianStorage3.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage3.weight, 0);
    }
}
