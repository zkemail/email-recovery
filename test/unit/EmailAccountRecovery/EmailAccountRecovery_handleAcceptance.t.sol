// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { RecoveryController } from "src/test/RecoveryController.sol";
import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";

contract EmailAccountRecoveryTest_handleAcceptance is EmailAccountRecoveryBase {
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

    function testExpectRevertHandleAcceptanceInvalidRecoveredAccount() public {
        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        emailAuthMsg.templateId = recoveryController.computeAcceptanceTemplateId(0);
        emailAuthMsg.commandParams[0] = abi.encode(address(0x0)); // Invalid account

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid command params"));
        recoveryController.handleAcceptance(emailAuthMsg, 0);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidTemplateId() public {
        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        emailAuthMsg.templateId = 999; // invalid template id
        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(address(simpleWallet));
        emailAuthMsg.commandParams = commandParamsForAcceptance;

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid template id"));
        recoveryController.handleAcceptance(emailAuthMsg, 0);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidEmailAuthMsgStructure() public {
        requestGuardian();

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );

        uint256 templateIdx = 0;

        // Create an invalid EmailAuthMsg with empty commandParams
        EmailAuthMsg memory emailAuthMsg;
        emailAuthMsg.templateId = recoveryController.computeAcceptanceTemplateId(templateIdx);
        emailAuthMsg.commandParams = new bytes[](0); // Invalid structure

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid command params"));
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidVerifier() public {
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

        // Set Verifier address to address(0)
        vm.store(
            address(recoveryController),
            bytes32(uint256(0)), // Assuming Verifier is the 1st storage slot in RecoveryController
            bytes32(uint256(0))
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid verifier address"));
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidDKIMRegistry() public {
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

        // Set DKIMRegistry address to address(0)
        vm.store(
            address(recoveryController),
            bytes32(uint256(1)), // Assuming DKIMRegistry is the 2nd storage slot in
                // RecoveryController
            bytes32(uint256(0))
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid dkim registry address"));
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidEmailAuthImplementationAddr() public {
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

        // Set EmailAuthImplementationAddr address to address(0)
        vm.store(
            address(recoveryController),
            bytes32(uint256(2)), // Assuming EmailAuthImplementationAddr is the 3rd storage slot in
                // RecoveryController
            bytes32(uint256(0))
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(
            abi.encodeWithSelector(ERC1967Utils.ERC1967InvalidImplementation.selector, address(0))
        );
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidController() public {
        // First, request and accept a guardian
        requestGuardian();
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

        vm.prank(someRelayer);
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.ACCEPTED),
            "Guardian should be accepted"
        );

        // Now, set an invalid controller for the guardian's EmailAuth contract
        address invalidController = address(0x1234);
        vm.mockCall(
            guardian,
            abi.encodeWithSelector(bytes4(keccak256("controller()"))),
            abi.encode(invalidController)
        );

        // Try to handle acceptance again, which should fail due to invalid controller
        vm.expectRevert("invalid controller");
        vm.prank(someRelayer);
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function testHandleAcceptance() public {
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

    function testExpectRevertHandleAcceptanceGuardianStatusMustBeRequested() public {
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
        emailAuthMsg.proof.accountSalt = 0x0;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("status must be REQUESTED"));
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidTemplateIndex() public {
        requestGuardian();

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );

        uint256 templateIdx = 1;

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

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid template index"));
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidCommandParams() public {
        requestGuardian();

        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );

        uint256 templateIdx = 0;

        EmailAuthMsg memory emailAuthMsg = buildEmailAuthMsg();
        uint256 templateId = recoveryController.computeAcceptanceTemplateId(templateIdx);
        emailAuthMsg.templateId = templateId;
        bytes[] memory commandParamsForAcceptance = new bytes[](2);
        commandParamsForAcceptance[0] = abi.encode(address(simpleWallet));
        commandParamsForAcceptance[1] = abi.encode(address(simpleWallet));
        emailAuthMsg.commandParams = commandParamsForAcceptance;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid command params"));
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }

    function testExpectRevertHandleAcceptanceInvalidWalletAddressInEmail() public {
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
        commandParamsForAcceptance[0] = abi.encode(address(0x0));
        emailAuthMsg.commandParams = commandParamsForAcceptance;

        vm.mockCall(
            address(recoveryController.emailAuthImplementationAddr()),
            abi.encodeWithSelector(EmailAuth.authEmail.selector, emailAuthMsg),
            abi.encode(0x0)
        );

        vm.startPrank(someRelayer);
        vm.expectRevert(bytes("invalid account in email"));
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        vm.stopPrank();
    }
}
