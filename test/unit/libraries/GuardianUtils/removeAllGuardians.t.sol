// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import {
    EnumerableGuardianMap,
    GuardianStorage,
    GuardianStatus
} from "src/libraries/EnumerableGuardianMap.sol";
import { GuardianUtils } from "src/libraries/GuardianUtils.sol";

contract GuardianUtils_removeAllGuardians_Test is UnitBase {
    using GuardianUtils for mapping(address => EnumerableGuardianMap.AddressToGuardianMap);

    function setUp() public override {
        super.setUp();
    }

    function test_RemoveAllGuardians_Succeeds() public {
        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        acceptGuardian(accountSalt3);

        emailRecoveryManager.exposed_removeAllGuardians(accountAddress);

        GuardianStorage memory guardianStorage1 =
            emailRecoveryManager.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage1.weight, 0);

        GuardianStorage memory guardianStorage2 =
            emailRecoveryManager.getGuardian(accountAddress, guardian2);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage2.weight, 0);

        GuardianStorage memory guardianStorage3 =
            emailRecoveryManager.getGuardian(accountAddress, guardian3);
        assertEq(uint256(guardianStorage3.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage3.weight, 0);
    }
}
