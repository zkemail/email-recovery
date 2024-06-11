// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract ZkEmailRecovery_getRecoveryConfig_Test is UnitBase {
    EmailRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new EmailRecoveryModule{ salt: "test salt" }(address(emailRecoveryManager));
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_GetRecoveryConfig_Succeeds() public { }
}
