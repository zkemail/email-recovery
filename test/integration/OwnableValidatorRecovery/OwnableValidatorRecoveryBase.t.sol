// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";

import { EmailAuthMsg, EmailProof } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { IEmailAccountRecovery } from "src/interfaces/IEmailAccountRecovery.sol";
import { IntegrationBase } from "../IntegrationBase.t.sol";

abstract contract OwnableValidatorRecoveryBase is IntegrationBase {
    EmailRecoverySubjectHandler emailRecoveryHandler;
    EmailRecoveryManager emailRecoveryManager;

    function setUp() public virtual override {
        super.setUp();

        emailRecoveryHandler = new EmailRecoverySubjectHandler();

        // Deploy EmailRecoveryManager
        emailRecoveryManager = new EmailRecoveryManager(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );

        // Compute guardian addresses
        guardian1 = emailRecoveryManager.computeEmailAuthAddress(accountSalt1);
        guardian2 = emailRecoveryManager.computeEmailAuthAddress(accountSalt2);
        guardian3 = emailRecoveryManager.computeEmailAuthAddress(accountSalt3);

        guardians = new address[](3);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardians[2] = guardian3;
    }

    // Helper functions

    function generateMockEmailProof(
        string memory subject,
        bytes32 nullifier,
        bytes32 accountSalt
    )
        public
        view
        returns (EmailProof memory)
    {
        EmailProof memory emailProof;
        emailProof.domainName = "gmail.com";
        emailProof.publicKeyHash = bytes32(
            vm.parseUint(
                "6632353713085157925504008443078919716322386156160602218536961028046468237192"
            )
        );
        emailProof.timestamp = block.timestamp;
        emailProof.maskedSubject = subject;
        emailProof.emailNullifier = nullifier;
        emailProof.accountSalt = accountSalt;
        emailProof.isCodeExist = true;
        emailProof.proof = bytes("0");

        return emailProof;
    }

    function acceptanceSubjectTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](5);
        templates[0][0] = "Accept";
        templates[0][1] = "guardian";
        templates[0][2] = "request";
        templates[0][3] = "for";
        templates[0][4] = "{ethAddr}";
        return templates;
    }

    function recoverySubjectTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](11);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "via";
        templates[0][4] = "recovery";
        templates[0][5] = "module";
        templates[0][6] = "{ethAddr}";
        templates[0][7] = "using";
        templates[0][8] = "recovery";
        templates[0][9] = "hash";
        templates[0][10] = "{string}";
        return templates;
    }

    function acceptGuardian(bytes32 accountSalt) public {
        // Uncomment if getting "invalid subject" errors. Sometimes the subject needs updating after
        // certain changes
        // console2.log("accountAddress: ", accountAddress);

        string memory subject =
            "Accept guardian request for 0x19F55F3fE4c8915F21cc92852CD8E924998fDa38";
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(accountAddress);
        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryManager.computeAcceptanceTemplateId(templateIdx),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });

        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function handleRecovery(
        address recoveryModule,
        bytes32 calldataHash,
        bytes32 accountSalt
    )
        public
    {
        // Uncomment if getting "invalid subject" errors. Sometimes the subject needs updating after
        // certain changes
        // console2.log("accountAddress: ", accountAddress);
        // console2.log("recoveryModule: ", recoveryModule);
        // console2.log("calldataHash:");
        // console2.logBytes32(calldataHash);

        // TODO: Ideally do this dynamically
        string memory calldataHashString =
            "0x774e575ec8d6368bbf9b564bd5827574b9f5f6c960e0f6ff9179eca3090df060";

        string memory subject = string.concat(
            "Recover account 0x19F55F3fE4c8915F21cc92852CD8E924998fDa38 via recovery module 0x2E15d2c3aBFfA78dA67Ebb55139902b85B746765 using recovery hash ",
            calldataHashString
        );
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](3);
        subjectParamsForRecovery[0] = abi.encode(accountAddress);
        subjectParamsForRecovery[1] = abi.encode(recoveryModule);
        subjectParamsForRecovery[2] = abi.encode(calldataHashString);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryManager.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        IEmailAccountRecovery(address(emailRecoveryManager)).handleRecovery(
            emailAuthMsg, templateIdx
        );
    }
}