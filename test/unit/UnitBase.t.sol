// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {Test} from "forge-std/Test.sol";

import {RhinestoneModuleKit, AccountInstance} from "modulekit/ModuleKit.sol";
import {ECDSAOwnedDKIMRegistry} from "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import {EmailAuth, EmailAuthMsg, EmailProof} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {ZkEmailRecoveryHarness} from "./ZkEmailRecoveryHarness.sol";
import {IEmailAccountRecovery} from "src/interfaces/IEmailAccountRecovery.sol";
import {MockGroth16Verifier} from "src/test/MockGroth16Verifier.sol";

abstract contract UnitBase is RhinestoneModuleKit, Test {
    // ZK Email contracts and variables
    address zkEmailDeployer = vm.addr(1);
    ECDSAOwnedDKIMRegistry ecdsaOwnedDkimRegistry;
    MockGroth16Verifier verifier;
    EmailAuth emailAuthImpl;

    ZkEmailRecoveryHarness zkEmailRecovery;

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
    uint templateIdx;

    // Account salts
    bytes32 accountSalt1;
    bytes32 accountSalt2;
    bytes32 accountSalt3;

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;

    function setUp() public virtual {
        init();

        // Create ZK Email contracts
        vm.startPrank(zkEmailDeployer);
        ecdsaOwnedDkimRegistry = new ECDSAOwnedDKIMRegistry(zkEmailDeployer);
        string memory signedMsg = ecdsaOwnedDkimRegistry.computeSignedMsg(
            ecdsaOwnedDkimRegistry.SET_PREFIX(),
            selector,
            domainName,
            publicKeyHash
        );
        bytes32 digest = ECDSA.toEthSignedMessageHash(bytes(signedMsg));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        ecdsaOwnedDkimRegistry.setDKIMPublicKeyHash(
            selector,
            domainName,
            publicKeyHash,
            signature
        );

        verifier = new MockGroth16Verifier();
        emailAuthImpl = new EmailAuth();
        vm.stopPrank();

        // create owners
        owner = vm.createWallet("owner").addr;
        newOwner = vm.createWallet("newOwner").addr;
        address[] memory owners = new address[](1);
        owners[0] = owner;

        // Deploy ZkEmailRecovery
        zkEmailRecovery = new ZkEmailRecoveryHarness(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl)
        );

        // Deploy and fund the account
        instance = makeAccountInstance("account");
        accountAddress = instance.account;
        vm.deal(address(instance.account), 10 ether);

        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        accountSalt3 = keccak256(abi.encode("account salt 3"));

        // Compute guardian addresses
        guardian1 = zkEmailRecovery.computeEmailAuthAddress(accountSalt1);
        guardian2 = zkEmailRecovery.computeEmailAuthAddress(accountSalt2);
        guardian3 = zkEmailRecovery.computeEmailAuthAddress(accountSalt3);

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
    }

    // Helper functions

    function generateMockEmailProof(
        string memory subject,
        bytes32 nullifier,
        bytes32 accountSalt
    ) public returns (EmailProof memory) {
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
        // Uncomment if getting "invalid subject" errors. Sometimes the subject needs updating after certain changes
        // console2.log("accountAddress: ", accountAddress);

        address router = zkEmailRecovery.getRouterForAccount(accountAddress);
        string
            memory subject = "Accept guardian request for 0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52";
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(
            subject,
            nullifier,
            accountSalt
        );

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(accountAddress);
        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: zkEmailRecovery.computeAcceptanceTemplateId(
                templateIdx
            ),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });

        IEmailAccountRecovery(router).handleAcceptance(
            emailAuthMsg,
            templateIdx
        );
    }

    function handleRecovery(
        address recoveryModule,
        bytes32 accountSalt
    ) public {
        // Uncomment if getting "invalid subject" errors. Sometimes the subject needs updating after certain changes
        // console2.log("accountAddress: ", accountAddress);
        // console2.log("newOwner:       ", newOwner);
        // console2.log("recoveryModule: ", recoveryModule);

        address router = zkEmailRecovery.getRouterForAccount(accountAddress);
        string
            memory subject = "Recover account 0x50Bc6f1F08ff752F7F5d687F35a0fA25Ab20EF52 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x344433E549E3F84B68D1aAC5b416Ac5cE2Be1063";
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        uint256 templateIdx = 0;
        EmailProof memory emailProof = generateMockEmailProof(
            subject,
            nullifier,
            accountSalt
        );

        bytes[] memory subjectParamsForRecovery = new bytes[](3);
        subjectParamsForRecovery[0] = abi.encode(accountAddress);
        subjectParamsForRecovery[1] = abi.encode(newOwner);
        subjectParamsForRecovery[2] = abi.encode(recoveryModule);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: zkEmailRecovery.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        IEmailAccountRecovery(router).handleRecovery(emailAuthMsg, templateIdx);
    }
}
