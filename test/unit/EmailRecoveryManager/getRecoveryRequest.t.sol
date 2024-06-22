// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {IEmailRecoveryManager} from "src/interfaces/IEmailRecoveryManager.sol";
import {EmailRecoveryModule} from "src/modules/EmailRecoveryModule.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract EmailRecoveryManager_getRecoveryRequest_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_GetRecoveryRequest_Succeeds() public {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);

        IEmailRecoveryManager.RecoveryRequest
            memory recoveryRequest = emailRecoveryManager.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.calldataHashString, "");
    }
}
