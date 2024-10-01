// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_getRecoveryRequest_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_GetRecoveryRequest_Succeeds() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, 1);
        assertEq(recoveryDataHash, recoveryDataHash);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, false);
    }
}
