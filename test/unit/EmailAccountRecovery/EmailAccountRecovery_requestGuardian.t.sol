// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { RecoveryController } from "src/test/RecoveryController.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";

contract EmailAccountRecoveryTest_requestGuardian is EmailAccountRecoveryBase {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
    }

    function testExpectRevertRequestGuardianRecoveryInProgress() public {
        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);

        // Simulate recovery in progress
        stdstore.target(address(recoveryController)).sig("isRecovering(address)").with_key(
            address(zkEmailDeployer)
        ).checked_write(true);

        vm.expectRevert(bytes("recovery in progress"));
        recoveryController.requestGuardian(address(0x123)); // Try to request a new guardian
        vm.stopPrank();
    }

    function testExpectRevertRequestGuardianInvalidGuardian() public {
        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.NONE)
        );

        vm.startPrank(zkEmailDeployer);
        vm.expectRevert(bytes("invalid guardian"));
        recoveryController.requestGuardian(address(0x0));
        vm.stopPrank();
    }

    function testExpectRevertRequestGuardianGuardianStatusMustBeNone() public {
        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.NONE)
        );

        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);
        vm.expectRevert(bytes("guardian status must be NONE"));
        recoveryController.requestGuardian(guardian);
        vm.stopPrank();
    }

    function testRequestGuardian() public {
        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.NONE)
        );

        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);
        vm.stopPrank();

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );
    }

    function testMultipleGuardianRequests() public {
        address anotherGuardian = vm.addr(9);
        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);
        recoveryController.requestGuardian(anotherGuardian); // Assuming anotherGuardian is defined
        vm.stopPrank();

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );
        assertEq(
            uint256(recoveryController.guardians(anotherGuardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );
    }
}
