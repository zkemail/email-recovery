// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EmailAuthMsg, EmailProof } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SubjectUtils } from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { EmailRecoveryFactory } from "src/EmailRecoveryFactory.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { IntegrationBase } from "../IntegrationBase.t.sol";

abstract contract OwnableValidatorRecoveryBase is IntegrationBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;
    using Strings for address;

    EmailRecoveryFactory emailRecoveryFactory;
    EmailRecoverySubjectHandler emailRecoveryHandler;
    EmailRecoveryManager emailRecoveryManager;

    address emailRecoveryManagerAddress;
    address recoveryModuleAddress;

    OwnableValidator validator;
    bytes4 functionSelector;
    bytes recoveryCalldata;
    bytes32 calldataHash;

    function setUp() public virtual override {
        super.setUp();

        emailRecoveryFactory = new EmailRecoveryFactory();
        emailRecoveryHandler = new EmailRecoverySubjectHandler();

        // Deploy EmailRecoveryManager & EmailRecoveryModule
        (emailRecoveryManagerAddress, recoveryModuleAddress) = emailRecoveryFactory
            .deployModuleAndManager(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
        emailRecoveryManager = EmailRecoveryManager(emailRecoveryManagerAddress);

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        functionSelector = bytes4(keccak256(bytes("changeOwner(address,address,address)")));
        recoveryCalldata = abi.encodeWithSignature(
            "changeOwner(address,address,address)", accountAddress, recoveryModuleAddress, newOwner
        );
        calldataHash = keccak256(recoveryCalldata);

        // Compute guardian addresses
        guardian1 = emailRecoveryManager.computeEmailAuthAddress(accountSalt1);
        guardian2 = emailRecoveryManager.computeEmailAuthAddress(accountSalt2);
        guardian3 = emailRecoveryManager.computeEmailAuthAddress(accountSalt3);

        guardians = new address[](3);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardians[2] = guardian3;

        // Install modules
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, recoveryModuleAddress)
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                address(validator),
                functionSelector,
                guardians,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });
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
        string memory accountString = SubjectUtils.addressToChecksumHexString(accountAddress);
        string memory subject = string.concat("Accept guardian request for ", accountString);
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
        string memory accountString = SubjectUtils.addressToChecksumHexString(accountAddress);
        string memory calldataHashString = uint256(calldataHash).toHexString(32);
        string memory recoveryModuleString = SubjectUtils.addressToChecksumHexString(recoveryModule);

        string memory subjectPart1 = string.concat("Recover account ", accountString);
        string memory subjectPart2 = string.concat(" via recovery module ", recoveryModuleString);
        string memory subjectPart3 = string.concat(" using recovery hash ", calldataHashString);
        string memory subject = string.concat(subjectPart1, subjectPart2, subjectPart3);

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
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }
}
