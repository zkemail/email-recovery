// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { EmailRecoveryFactory } from "../../../src/EmailRecoveryFactory.sol";

contract EmailRecoveryFactory_deployModuleAndManager_Test is UnitBase {
    function setUp() public override {
        super.setUp();
        emailRecoveryFactory = new EmailRecoveryFactory();
    }

    function test_DeployModuleAndManager_Succeeds() public {
        emailRecoveryFactory.deployModuleAndManager(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
    }
}
