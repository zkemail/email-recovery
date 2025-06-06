// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { RecoveryController } from "src/test/RecoveryController.sol";
import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";

contract EmailAccountRecoveryTest_handleRecovery is EmailAccountRecoveryBase {
    function setUp() public override {
        super.setUp();
    }

    function requestGuardian() public {
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

    function handleAcceptance() public {
        requestGuardian();

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        uint256 templateId = recoveryController.computeAcceptanceTemplateId(templateIdx);
        emailAuthMsg.templateId = templateId;
        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(address(simpleWallet));
        emailAuthMsg.commandParams = commandParamsForAcceptance;

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

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.ACCEPTED)
        );
    }

    function testExpectRevertHandleRecoveryInvalidRecoveredAccount() public {
        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        emailAuthMsg.templateId = recoveryController.computeRecoveryTemplateId(0);
        emailAuthMsg.commandParams[0] = abi.encode(address(0x0)); // Invalid account

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid account in email"));
        recoveryController.handleRecovery(emailAuthMsg, 0);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryInvalidAccountInEmail() public {
        handleAcceptance();

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        emailAuthMsg.templateId = recoveryController.computeRecoveryTemplateId(templateIdx);
        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(address(0x0)); // Invalid account
        commandParamsForRecovery[1] = abi.encode(newSigner);
        emailAuthMsg.commandParams = commandParamsForRecovery;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid account in email"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryGuardianCodeLengthZero() public {
        handleAcceptance();

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        emailAuthMsg.templateId = recoveryController.computeRecoveryTemplateId(templateIdx);
        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(simpleWallet);
        commandParamsForRecovery[1] = abi.encode(newSigner);
        emailAuthMsg.commandParams = commandParamsForRecovery;

        // Mock guardian with no code
        vm.etch(guardian, "");

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("guardian is not deployed"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryTemplateIdMismatch() public {
        handleAcceptance();

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        emailAuthMsg.templateId = 999; // Invalid template ID
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
        vm.expectRevert(bytes("invalid template id"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryAuthEmailFailure() public {
        handleAcceptance();

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        emailAuthMsg.templateId = recoveryController.computeRecoveryTemplateId(templateIdx);
        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(simpleWallet);
        commandParamsForRecovery[1] = abi.encode(newSigner);
        emailAuthMsg.commandParams = commandParamsForRecovery;

        // Mock authEmail to fail
        vm.mockCallRevert(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            "REVERT_MESSAGE"
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(); // Expect any revert due to authEmail failure
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testHandleRecovery() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
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

    function testExpectRevertHandleRecoveryGuardianIsNotDeployed() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
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
        emailAuthMsg.proof.accountSalt = 0x0;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("guardian is not deployed"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryInvalidTemplateId() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0x0)
        );

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
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
        vm.expectRevert(bytes("invalid template id"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryGuardianStatusMustBeAccepted() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
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
        emailAuthMsg.proof.accountSalt = 0x0;

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("guardian is not deployed"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryInvalidTemplateIndex() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0x0)
        );
        uint256 templateIdx = 1;

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
        vm.expectRevert(bytes("invalid template index"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryInvalidCommandParams() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0x0)
        );
        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        uint256 templateId = recoveryController.computeRecoveryTemplateId(templateIdx);
        emailAuthMsg.templateId = templateId;
        bytes[] memory commandParamsForRecovery = new bytes[](3);
        commandParamsForRecovery[0] = abi.encode(simpleWallet);
        commandParamsForRecovery[1] = abi.encode(newSigner);
        commandParamsForRecovery[1] = abi.encode(address(0x0));
        emailAuthMsg.commandParams = commandParamsForRecovery;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid command params"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleRecoveryInvalidNewSigner() public {
        handleAcceptance();

        assertEq(recoveryController.isRecovering(address(simpleWallet)), false);
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), zkEmailDeployer);
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0x0)
        );
        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        uint256 templateId = recoveryController.computeRecoveryTemplateId(templateIdx);
        emailAuthMsg.templateId = templateId;
        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(simpleWallet);
        commandParamsForRecovery[1] = abi.encode(address(0x0));
        emailAuthMsg.commandParams = commandParamsForRecovery;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid new signer"));
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }
}
