// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg, EmailProof } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SubjectUtils } from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { EmailRecoveryManagerHarness } from "./EmailRecoveryManagerHarness.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { SafeRecoverySubjectHandlerHarness } from "./SafeRecoverySubjectHandlerHarness.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { IntegrationBase } from "../integration/IntegrationBase.t.sol";

abstract contract SafeUnitBase is IntegrationBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    EmailRecoveryFactory emailRecoveryFactory;
    SafeRecoverySubjectHandlerHarness safeRecoverySubjectHandler;
    EmailRecoveryManager emailRecoveryManager;
    address emailRecoveryManagerAddress;
    address recoveryModuleAddress;

    bytes4 functionSelector;
    bytes recoveryCalldata;
    bytes32 calldataHash;
    bytes isInstalledContext;

    /**
     * Helper function to return if current account type is safe or not
     */
    function isAccountTypeSafe() public returns (bool) {
        string memory currentAccountType = vm.envOr("ACCOUNT_TYPE", string(""));
        if (Strings.equal(currentAccountType, "SAFE")) {
            return true;
        } else {
            return false;
        }
    }

    function skipIfNotSafeAccountType() public {
        if (isAccountTypeSafe()) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
    }

    function setUp() public virtual override {
        if (!isAccountTypeSafe()) {
            return;
        }
        super.setUp();

        // Deploy handler, manager and module
        safeRecoverySubjectHandler = new SafeRecoverySubjectHandlerHarness();
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));

        emailRecoveryManager = new EmailRecoveryManagerHarness(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl),
            address(safeRecoverySubjectHandler)
        );
        emailRecoveryManagerAddress = address(emailRecoveryManager);

        UniversalEmailRecoveryModule emailRecoveryModule =
            new UniversalEmailRecoveryModule(emailRecoveryManagerAddress);
        recoveryModuleAddress = address(emailRecoveryModule);
        emailRecoveryManager.initialize(recoveryModuleAddress);

        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));
        address previousOwnerInLinkedList = address(1);
        // address previousOwnerInLinkedList =
        //     safeRecoverySubjectHandler.previousOwnerInLinkedList(accountAddress, owner);
        bytes memory swapOwnerCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", previousOwnerInLinkedList, owner1, newOwner1
        );
        bytes memory recoveryCalldata = abi.encode(accountAddress1, swapOwnerCalldata);
        calldataHash = keccak256(recoveryCalldata);
        isInstalledContext = bytes("0");

        // Compute guardian addresses
        guardians1 = new address[](3);
        guardians1[0] =
            emailRecoveryManager.computeEmailAuthAddress(instance1.account, accountSalt1);
        guardians1[1] =
            emailRecoveryManager.computeEmailAuthAddress(instance1.account, accountSalt2);
        guardians1[2] =
            emailRecoveryManager.computeEmailAuthAddress(instance1.account, accountSalt3);

        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                accountAddress1,
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });
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

    function acceptGuardian(address account, bytes32 accountSalt) public {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory subject = string.concat("Accept guardian request for ", accountString);

        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));
        uint256 templateIdx = 0;
        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(account);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryManager.computeAcceptanceTemplateId(templateIdx),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function handleRecovery(address account, bytes32 accountSalt) public {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory calldataHashString = uint256(calldataHash).toHexString(32);
        string memory recoveryModuleString =
            SubjectUtils.addressToChecksumHexString(recoveryModuleAddress);

        string memory subjectPart1 = string.concat("Recover account ", accountString);
        string memory subjectPart2 = string.concat(" via recovery module ", recoveryModuleString);
        string memory subjectPart3 = string.concat(" using recovery hash ", calldataHashString);
        string memory subject = string.concat(subjectPart1, subjectPart2, subjectPart3);
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](3);
        subjectParamsForRecovery[0] = abi.encode(account);
        subjectParamsForRecovery[1] = abi.encode(recoveryModuleAddress);
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
