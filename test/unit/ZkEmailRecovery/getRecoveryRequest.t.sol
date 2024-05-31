// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract ZkEmailRecovery_getRecoveryRequest_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_GetRecoveryRequest_Succeeds() public { }
}
