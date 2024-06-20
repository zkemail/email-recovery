// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    AccountInstance,
    ModuleKitHelpers,
    ModuleKitUserOp
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { ECDSAOwnedDKIMRegistry } from
    "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { SubjectUtils } from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { EmailRecoveryManagerHarness } from "./EmailRecoveryManagerHarness.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { EmailRecoveryModuleHarness } from "./EmailRecoveryModuleHarness.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoveryFactory } from "src/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";

abstract contract UnitBase is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;

    // ZK Email contracts and variables
    address zkEmailDeployer = vm.addr(1);
    ECDSAOwnedDKIMRegistry dkimRegistry;
    MockGroth16Verifier verifier;
    EmailAuth emailAuthImpl;

    EmailRecoveryFactory emailRecoveryFactory;
    EmailRecoverySubjectHandler emailRecoveryHandler;
    EmailRecoveryManagerHarness emailRecoveryManager;
    EmailRecoveryModuleHarness emailRecoveryModule;

    // EmailRecoveryManager emailRecoveryManager;
    address emailRecoveryManagerAddress;
    address recoveryModuleAddress;
    address validatorAddress;

    OwnableValidator validator;
    bytes4 functionSelector;
    bytes recoveryCalldata;
    bytes32 calldataHash;

    // account and owners
    AccountInstance instance;
    address accountAddress;
    address owner;
    address newOwner;

    // recovery config
    address[] guardians;
    address guardian1;
    address guardian2;
    address guardian3;
    uint256[] guardianWeights;
    uint256 totalWeight;
    uint256 delay;
    uint256 expiry;
    uint256 threshold;
    uint256 templateIdx;

    // Account salts
    bytes32 accountSalt1;
    bytes32 accountSalt2;
    bytes32 accountSalt3;

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash = 0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;

    function setUp() public virtual {
        init();

        // Create ZK Email contracts
        vm.startPrank(zkEmailDeployer);
        dkimRegistry = new ECDSAOwnedDKIMRegistry(zkEmailDeployer);
        string memory signedMsg = dkimRegistry.computeSignedMsg(
            dkimRegistry.SET_PREFIX(), selector, domainName, publicKeyHash
        );
        bytes32 digest = ECDSA.toEthSignedMessageHash(bytes(signedMsg));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        dkimRegistry.setDKIMPublicKeyHash(selector, domainName, publicKeyHash, signature);

        verifier = new MockGroth16Verifier();
        emailAuthImpl = new EmailAuth();
        vm.stopPrank();

        // create owners
        owner = vm.createWallet("owner").addr;
        newOwner = vm.createWallet("newOwner").addr;
        address[] memory owners = new address[](1);
        owners[0] = owner;

        // Deploy handler, manager and module
        emailRecoveryHandler = new EmailRecoverySubjectHandler();
        emailRecoveryFactory = new EmailRecoveryFactory();

        emailRecoveryManager = new EmailRecoveryManagerHarness(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
        emailRecoveryManagerAddress = address(emailRecoveryManager);

        emailRecoveryModule = new EmailRecoveryModuleHarness(emailRecoveryManagerAddress);
        recoveryModuleAddress = address(emailRecoveryModule);
        emailRecoveryManager.initialize(recoveryModuleAddress);

        // Deploy and fund the account
        instance = makeAccountInstance("account");
        accountAddress = instance.account;
        vm.deal(address(instance.account), 10 ether);

        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        accountSalt3 = keccak256(abi.encode("account salt 3"));

        // Compute guardian addresses
        guardian1 = emailRecoveryManager.computeEmailAuthAddress(accountSalt1);
        guardian2 = emailRecoveryManager.computeEmailAuthAddress(accountSalt2);
        guardian3 = emailRecoveryManager.computeEmailAuthAddress(accountSalt3);

        guardians = new address[](3);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardians[2] = guardian3;

        // Set recovery config variables
        guardianWeights = new uint256[](3);
        guardianWeights[0] = 1;
        guardianWeights[1] = 2;
        guardianWeights[2] = 1;
        totalWeight = 4;
        delay = 1 seconds;
        expiry = 2 weeks;
        threshold = 3;
        templateIdx = 0;

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);
        functionSelector = bytes4(keccak256(bytes("changeOwner(address,address,address)")));
        recoveryCalldata = abi.encodeWithSignature(
            "changeOwner(address,address,address)", accountAddress, recoveryModuleAddress, newOwner
        );
        calldataHash = keccak256(recoveryCalldata);

        // Install modules
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner, recoveryModuleAddress)
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                validatorAddress, functionSelector, guardians, guardianWeights, threshold, delay, expiry
            )
        });
    }

    // Helper functions

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

    function acceptGuardian(bytes32 accountSalt) public {
        string memory accountString = SubjectUtils.addressToChecksumHexString(accountAddress);
        string memory subject = string.concat("Accept guardian request for ", accountString);

        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

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
