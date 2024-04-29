// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import "forge-std/console2.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, ModuleKitUserOp, AccountInstance, UserOpData} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/external/ERC7579.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";

import {ZkEmailRecovery} from "src/ZkEmailRecovery.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidator} from "src/test/OwnableValidator.sol";
import {IGuardianManager} from "src/interfaces/IGuardianManager.sol";
import {IEmailAccountRecovery} from "src/EmailAccountRecoveryRouter.sol";

import {EmailAuth, EmailAuthMsg, EmailProof} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {ECDSAOwnedDKIMRegistry} from "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import {MockGroth16Verifier} from "../src/test/MockGroth16Verifier.sol";

contract ZkEmailRecoveryTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    ZkEmailRecovery internal executor;
    OwnableValidator internal validator;

    address public owner;
    address public newOwner;

    // ZK Email contracts and variables
    address zkEmailDeployer = vm.addr(1);
    ECDSAOwnedDKIMRegistry ecdsaOwnedDkimRegistry;
    MockGroth16Verifier verifier;
    bytes32 accountSalt1;
    bytes32 accountSalt2;

    address guardian1;
    address guardian2;
    uint256 recoveryDelay;
    uint256 threshold;

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;

    function setUp() public {
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
        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));

        EmailAuth emailAuthImpl = new EmailAuth();
        vm.stopPrank();

        owner = vm.createWallet("owner").addr;
        newOwner = vm.createWallet("newOwner").addr;

        address[] memory owners = new address[](1);
        owners[0] = owner;

        // Create the executor
        executor = new ZkEmailRecovery(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl)
        );
        vm.label(address(executor), "ZkEmailRecovery");
        validator = new OwnableValidator();

        // Create the account and install the executor
        instance = makeAccountInstance("ZkEmailRecovery");
        vm.deal(address(instance.account), 10 ether);

        guardian1 = executor.computeEmailAuthAddress(accountSalt1);
        guardian2 = executor.computeEmailAuthAddress(accountSalt2);

        address[] memory guardians = new address[](2);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        recoveryDelay = 1 seconds;
        threshold = 2;

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encode(guardians, recoveryDelay, threshold)
        });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, address(executor))
        });
    }

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
            templateId: executor.computeAcceptanceTemplateId(templateIdx),
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
        address module,
        address newOwner,
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
        subjectParamsForRecovery[0] = abi.encode(newOwner);
        subjectParamsForRecovery[1] = abi.encode(module);
        subjectParamsForRecovery[2] = abi.encode(account);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: executor.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        IEmailAccountRecovery(router).handleRecovery(emailAuthMsg, templateIdx);
    }

    function testRecover() public {
        address accountAddress = instance.account;
        address router = executor.getRouterForAccount(instance.account);
        uint templateIdx = 0;

        // Accept guardian 1
        acceptGuardian(
            instance.account,
            router,
            "Accept guardian request for 0xA585Ae5039aa1248b64368bf63d24F06f8723d96",
            keccak256(abi.encode("nullifier 1")),
            accountSalt1,
            templateIdx
        );
        IGuardianManager.GuardianStatus guardianStatus1 = executor
            .getGuardianStatus(accountAddress, guardian1);
        assertEq(
            uint256(guardianStatus1),
            uint256(IGuardianManager.GuardianStatus.ACCEPTED)
        );

        // Accept guardian 2
        acceptGuardian(
            instance.account,
            router,
            "Accept guardian request for 0xA585Ae5039aa1248b64368bf63d24F06f8723d96",
            keccak256(abi.encode("nullifier 1")),
            accountSalt2,
            templateIdx
        );
        IGuardianManager.GuardianStatus guardianStatus2 = executor
            .getGuardianStatus(accountAddress, guardian2);
        assertEq(
            uint256(guardianStatus2),
            uint256(IGuardianManager.GuardianStatus.ACCEPTED)
        );

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        handleRecovery(
            accountAddress,
            address(validator),
            newOwner,
            router,
            "Update owner to 0x7240b687730BE024bcfD084621f794C2e4F8408f on module 0x0d9937747341468E77AdBcaddfA8B779Bcde8b98 for account 0xA585Ae5039aa1248b64368bf63d24F06f8723d96",
            keccak256(abi.encode("nullifier 2")),
            accountSalt1,
            templateIdx
        );
        IZkEmailRecovery.RecoveryRequest memory recoveryRequest = executor
            .getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.recoveryData, abi.encode(newOwner, validator));
        assertEq(recoveryRequest.approvalCount, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + recoveryDelay;
        handleRecovery(
            accountAddress,
            address(validator),
            newOwner,
            router,
            "Update owner to 0x7240b687730BE024bcfD084621f794C2e4F8408f on module 0x0d9937747341468E77AdBcaddfA8B779Bcde8b98 for account 0xA585Ae5039aa1248b64368bf63d24F06f8723d96",
            keccak256(abi.encode("nullifier 2")),
            accountSalt2,
            templateIdx
        );
        recoveryRequest = executor.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.recoveryData, abi.encode(newOwner, validator));
        assertEq(recoveryRequest.approvalCount, 2);

        vm.warp(block.timestamp + recoveryDelay);

        // Complete recovery
        IEmailAccountRecovery(router).completeRecovery();

        recoveryRequest = executor.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.recoveryData, new bytes(0));
        assertEq(recoveryRequest.approvalCount, 0);

        address updatedOwner = validator.owners(accountAddress);
        assertEq(updatedOwner, newOwner);
    }
}
