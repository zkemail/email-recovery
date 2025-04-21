// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { StdStorage, stdStorage } from "forge-std/StdStorage.sol";
import { console } from "forge-std/console.sol";
import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { RecoveryController } from "src/test/RecoveryController.sol";
import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";
import { SimpleWallet } from "src/test/SimpleWallet.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EmailAccountRecoveryTest_requestGuardian is EmailAccountRecoveryBase {
    using stdStorage for StdStorage;

    constructor() { }

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
        require(recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.NONE);

        vm.startPrank(zkEmailDeployer);
        vm.expectRevert(bytes("invalid guardian"));
        recoveryController.requestGuardian(address(0x0));
        vm.stopPrank();
    }

    function testExpectRevertRequestGuardianGuardianStatusMustBeNone() public {
        require(recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.NONE);

        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);
        vm.expectRevert(bytes("guardian status must be NONE"));
        recoveryController.requestGuardian(guardian);
        vm.stopPrank();
    }

    function testRequestGuardian() public {
        require(recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.NONE);

        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);
        vm.stopPrank();

        require(
            recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.REQUESTED
        );
    }

    function testMultipleGuardianRequests() public {
        address anotherGuardian = vm.addr(9);
        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);
        recoveryController.requestGuardian(anotherGuardian); // Assuming anotherGuardian is defined
        vm.stopPrank();

        require(
            recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.REQUESTED
        );
        require(
            recoveryController.guardians(anotherGuardian)
                == RecoveryController.GuardianStatus.REQUESTED
        );
    }
}
