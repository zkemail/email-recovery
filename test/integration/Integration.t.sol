// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import "forge-std/console2.sol";
import {RhinestoneModuleKit, AccountInstance} from "modulekit/ModuleKit.sol";
import {EmailAuth, EmailAuthMsg, EmailProof} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {ECDSAOwnedDKIMRegistry} from "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {ZkEmailRecovery} from "src/ZkEmailRecovery.sol";
import {IEmailAccountRecovery} from "src/interfaces/IEmailAccountRecovery.sol";
import {MockGroth16Verifier} from "src/test/MockGroth16Verifier.sol";

abstract contract Integration_Test is RhinestoneModuleKit, Test {
    // account and owners
    AccountInstance instance;
    address accountAddress;
    address owner;
    address newOwner;

    // ZK Email contracts and variables
    address zkEmailDeployer = vm.addr(1);
    ECDSAOwnedDKIMRegistry ecdsaOwnedDkimRegistry;
    MockGroth16Verifier verifier;
    ZkEmailRecovery zkEmailRecovery;
    bytes32 accountSalt1;
    bytes32 accountSalt2;

    // recovery config
    address[] guardians;
    address guardian1;
    address guardian2;
    uint256[] guardianWeights;
    uint256 delay;
    uint256 expiry;
    uint256 threshold;

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
        EmailAuth emailAuthImpl = new EmailAuth();
        vm.stopPrank();

        // Create owners
        owner = vm.createWallet("owner").addr;
        newOwner = vm.createWallet("newOwner").addr;
        address[] memory owners = new address[](1);
        owners[0] = owner;

        // Deploy and fund the account
        instance = makeAccountInstance("ZkEmailRecovery");
        accountAddress = instance.account;
        vm.deal(address(instance.account), 10 ether);

        // Deploy ZkEmailRecovery
        zkEmailRecovery = new ZkEmailRecovery(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl)
        );

        // Compute guardian addresses
        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        guardian1 = zkEmailRecovery.computeEmailAuthAddress(accountSalt1);
        guardian2 = zkEmailRecovery.computeEmailAuthAddress(accountSalt2);

        // Set recovery config variables
        guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardianWeights = new uint256[](2);
        guardianWeights[0] = 1;
        guardianWeights[1] = 1;
        delay = 1 seconds;
        expiry = 2 weeks;
        threshold = 2;
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

    function acceptGuardian(
        address account,
        // ZkEmailRecovery zkEmailRecovery,
        address router,
        string memory subject,
        bytes32 nullifier,
        bytes32 accountSalt,
        uint256 templateIdx
    ) public {
        EmailProof memory emailProof = generateMockEmailProof(
            subject,
            nullifier,
            accountSalt
        );

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(account);
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
        address account,
        address newOwner,
        address recoveryModule,
        address router,
        string memory subject,
        bytes32 nullifier,
        bytes32 accountSalt,
        uint256 templateIdx
    ) public {
        EmailProof memory emailProof = generateMockEmailProof(
            subject,
            nullifier,
            accountSalt
        );

        bytes[] memory subjectParamsForRecovery = new bytes[](3);
        subjectParamsForRecovery[0] = abi.encode(account);
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
