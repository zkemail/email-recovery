// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { RecoveryController } from "src/test/RecoveryController.sol";
import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";
import { SimpleWallet } from "src/test/SimpleWallet.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EmailAccountRecoveryForRejectRecoveryTest_rejectRecovery is EmailAccountRecoveryBase {
    constructor() { }

    function setUp() public override {
        super.setUp();
    }

    /**
     * Set up functions
     */
    function requestGuardian() public {
        require(recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.NONE);

        vm.startPrank(zkEmailDeployer);
        recoveryController.requestGuardian(guardian);
        vm.stopPrank();

        require(
            recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.REQUESTED
        );
    }

    function handleAcceptance() public {
        requestGuardian();

        require(
            recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.REQUESTED
        );

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(address(simpleWallet));
        emailAuthMsg.commandParams = commandParamsForAcceptance;
        address recoveredAccount = recoveryController.extractRecoveredAccountFromAcceptanceCommand(
            emailAuthMsg.commandParams, templateIdx
        );
        uint256 templateId = recoveryController.computeAcceptanceTemplateId(templateIdx);
        emailAuthMsg.templateId = templateId;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        // acceptGuardian is internal, we call handleAcceptance, which calls acceptGuardian
        // internally.
        vm.startPrank(someRelayer);
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();

        require(
            recoveryController.guardians(guardian) == RecoveryController.GuardianStatus.ACCEPTED
        );
    }

    function handleRecovery() public {
        handleAcceptance();

        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0x0)
        );

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        uint256 templateId = recoveryController.computeRecoveryTemplateId(templateIdx);
        emailAuthMsg.templateId = templateId;
        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(simpleWallet);
        commandParamsForRecovery[1] = abi.encode(newSigner);
        emailAuthMsg.commandParams = commandParamsForRecovery;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), true);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), newSigner);
        assertEq(
            recoveryController.currentTimelockOfAccount(address(simpleWallet)),
            block.timestamp + recoveryController.timelockPeriodOfAccount(address(simpleWallet))
        );
    }

    function testRejectRecovery() public {
        vm.warp(block.timestamp + 3 days);

        handleRecovery();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), true);
        assertEq(
            recoveryController.currentTimelockOfAccount(address(simpleWallet)),
            block.timestamp + recoveryController.timelockPeriodOfAccount(address(simpleWallet))
        );
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), newSigner);

        vm.warp(0);

        vm.startPrank(address(simpleWallet));
        recoveryController.rejectRecovery();
        vm.stopPrank();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0x0)
        );
    }

    function testExpectRevertRejectRecoveryRecoveryNotInProgress() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0x0)
        );

        vm.startPrank(zkEmailDeployer);
        vm.expectRevert(bytes("recovery not in progress"));
        recoveryController.rejectRecovery();
        vm.stopPrank();
    }

    function testExpectRevertRejectRecovery() public {
        vm.warp(block.timestamp + 1 days);

        handleRecovery();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), true);
        assertEq(
            recoveryController.currentTimelockOfAccount(address(simpleWallet)),
            block.timestamp + recoveryController.timelockPeriodOfAccount(address(simpleWallet))
        );
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), newSigner);

        vm.startPrank(address(simpleWallet));
        vm.warp(block.timestamp + 4 days);
        vm.expectRevert(bytes("timelock expired"));
        recoveryController.rejectRecovery();
        vm.stopPrank();
    }

    function testExpectRevertRejectRecoveryOwnableUnauthorizedAccount() public {
        handleRecovery();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), true);
        assertEq(
            recoveryController.currentTimelockOfAccount(address(simpleWallet)),
            block.timestamp + recoveryController.timelockPeriodOfAccount(address(simpleWallet))
        );
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), newSigner);

        vm.startPrank(zkEmailDeployer);
        vm.expectRevert("recovery not in progress");
        recoveryController.rejectRecovery();
        vm.stopPrank();
    }
}
