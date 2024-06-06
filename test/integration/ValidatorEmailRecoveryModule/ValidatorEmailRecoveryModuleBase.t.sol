// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";

import { EmailAuthMsg, EmailProof } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {SubjectUtils} from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import { ZkEmailRecovery } from "src/ZkEmailRecovery.sol";
import { IEmailAccountRecovery } from "src/interfaces/IEmailAccountRecovery.sol";
import { IntegrationBase } from "../IntegrationBase.t.sol";

abstract contract ValidatorEmailRecoveryModuleBase is IntegrationBase {
    ZkEmailRecovery zkEmailRecovery;

    function setUp() public virtual override {
        super.setUp();

        // Deploy ZkEmailRecovery
        zkEmailRecovery = new ZkEmailRecovery(
            address(verifier), address(ecdsaOwnedDkimRegistry), address(emailAuthImpl)
        );

        // Compute guardian addresses
        guardian1 = zkEmailRecovery.computeEmailAuthAddress(accountSalt1);
        guardian2 = zkEmailRecovery.computeEmailAuthAddress(accountSalt2);
        guardian3 = zkEmailRecovery.computeEmailAuthAddress(accountSalt3);

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

    function acceptanceSubjectTemplates()
        public
        pure
        returns (string[][] memory)
    {
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
        templates[0] = new string[](15);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "to";
        templates[0][4] = "new";
        templates[0][5] = "owner";
        templates[0][6] = "{ethAddr}";
        templates[0][7] = "using";
        templates[0][8] = "recovery";
        templates[0][9] = "module";
        templates[0][10] = "{ethAddr}";
        templates[0][11] = "and";
        templates[0][12] = "calldata";
        templates[0][13] = "hash";
        templates[0][14] = "{string}";
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
            templateId: zkEmailRecovery.computeAcceptanceTemplateId(templateIdx),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });

        zkEmailRecovery.handleAcceptance(accountAddress, emailAuthMsg, templateIdx);
    }

    function handleRecovery(address newOwner, address recoveryModule, bytes32 calldataHash, bytes32 accountSalt) public {
        // Uncomment if getting "invalid subject" errors. Sometimes the subject needs updating after
        // certain changes
        // console2.log("accountAddress: ", accountAddress);
        // console2.log("newOwner:       ", newOwner);
        // console2.log("recoveryModule: ", recoveryModule);
        // console2.log("calldataHash:");
        // console2.logBytes32(calldataHash);

        // TODO: Ideally do this dynamically
        string memory calldataHashString = "0x97b1d4ee156242fe89ddf0740066dbc1d684025f1d8b95e5fa67743608a243d0";

        string memory subject =
            "Recover account 0x19F55F3fE4c8915F21cc92852CD8E924998fDa38 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x98055f91baf53ba7F88A6Db946391950f9B4DD80 and calldata hash 0x97b1d4ee156242fe89ddf0740066dbc1d684025f1d8b95e5fa67743608a243d0";
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](4);
        subjectParamsForRecovery[0] = abi.encode(accountAddress);
        subjectParamsForRecovery[1] = abi.encode(newOwner);
        subjectParamsForRecovery[2] = abi.encode(recoveryModule);
        subjectParamsForRecovery[3] = abi.encode(calldataHashString);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: zkEmailRecovery.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        console2.log("1");
        zkEmailRecovery.handleRecovery(accountAddress, emailAuthMsg, templateIdx);
    }
}
