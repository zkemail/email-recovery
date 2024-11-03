// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailRecoveryManager_hasGuardianVoted_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_hasGuardianVoted_ReturnsFalseWhenGuardianHasNotVoted() public view {
        bool hasGuardianVoted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        assertFalse(hasGuardianVoted);
    }

    function test_hasGuardianVoted_ReturnsFalseWhenGuardianHasVotedButWrongAccount() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        bool hasGuardianVoted = emailRecoveryModule.hasGuardianVoted(accountAddress2, guardians1[0]);
        assertFalse(hasGuardianVoted);
    }

    function test_hasGuardianVoted_ReturnsFalseWhenAccountCorrectButWrongGuardian() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        bool hasGuardianVoted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertFalse(hasGuardianVoted);
    }

    function test_hasGuardianVoted_ReturnsTrueWhenGuardianHasVoted() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.warp(12 seconds);
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        bool hasGuardianVoted = emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        assertTrue(hasGuardianVoted);
    }
}
