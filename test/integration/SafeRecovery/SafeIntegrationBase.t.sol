// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg, EmailProof } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SubjectUtils } from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";
import { IntegrationBase } from "../IntegrationBase.t.sol";

abstract contract SafeIntegrationBase is IntegrationBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    SafeRecoverySubjectHandler safeRecoverySubjectHandler;
    EmailRecoveryManager emailRecoveryManager;
    address emailRecoveryManagerAddress;
    address recoveryModuleAddress;

    bytes isInstalledContext;
    bytes4 functionSelector;

    uint256 nullifierCount;

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

    function setUp() public virtual override {
        if (!isAccountTypeSafe()) {
            return;
        }
        super.setUp();

        // Deploy handler, manager and module
        safeRecoverySubjectHandler = new SafeRecoverySubjectHandler();

        emailRecoveryManager = new EmailRecoveryManager(
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

        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

        // Compute guardian addresses
        guardians1 = new address[](3);
        guardians1[0] = emailRecoveryManager.computeEmailAuthAddress(accountAddress1, accountSalt1);
        guardians1[1] = emailRecoveryManager.computeEmailAuthAddress(accountAddress1, accountSalt2);
        guardians1[2] = emailRecoveryManager.computeEmailAuthAddress(accountAddress1, accountSalt3);
        guardians2 = new address[](3);
        guardians2[0] =
            emailRecoveryManager.computeEmailAuthAddress(instance2.account, accountSalt1);
        guardians2[1] =
            emailRecoveryManager.computeEmailAuthAddress(instance2.account, accountSalt2);
        guardians2[2] =
            emailRecoveryManager.computeEmailAuthAddress(instance2.account, accountSalt3);
        guardians3 = new address[](3);
        guardians3[0] =
            emailRecoveryManager.computeEmailAuthAddress(instance3.account, accountSalt1);
        guardians3[1] =
            emailRecoveryManager.computeEmailAuthAddress(instance3.account, accountSalt2);
        guardians3[2] =
            emailRecoveryManager.computeEmailAuthAddress(instance3.account, accountSalt3);

        vm.prank(accountAddress1);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                address(accountAddress1),
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });
        vm.stopPrank();
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

    function getAccountSaltForGuardian(address guardian) public returns (bytes32) {
        if (guardian == guardians1[0]) {
            return accountSalt1;
        }
        if (guardian == guardians1[1]) {
            return accountSalt2;
        }
        if (guardian == guardians1[2]) {
            return accountSalt3;
        }

        revert("Invalid guardian address");
    }

    function generateNewNullifier() public returns (bytes32) {
        return keccak256(abi.encode(nullifierCount++));
    }

    function acceptGuardian(address account, address guardian) public {
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(account, guardian);
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function getAcceptanceEmailAuthMessage(
        address account,
        address guardian
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory subject = string.concat("Accept guardian request for ", accountString);
        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt = getAccountSaltForGuardian(guardian);

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(account);
        return EmailAuthMsg({
            templateId: emailRecoveryManager.computeAcceptanceTemplateId(templateIdx),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
    }

    function handleRecovery(
        address account,
        address oldOwner,
        address newOwner,
        address guardian
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, oldOwner, newOwner, guardian);
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        address oldOwner,
        address newOwner,
        address guardian
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory oldOwnerString = SubjectUtils.addressToChecksumHexString(oldOwner);
        string memory newOwnerString = SubjectUtils.addressToChecksumHexString(newOwner);
        string memory recoveryModuleString =
            SubjectUtils.addressToChecksumHexString(recoveryModuleAddress);

        string memory subject = string.concat(
            "Recover account ",
            accountString,
            " from old owner ",
            oldOwnerString,
            " to new owner ",
            newOwnerString,
            " using recovery module ",
            recoveryModuleString
        );
        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt = getAccountSaltForGuardian(guardian);

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](4);
        subjectParamsForRecovery[0] = abi.encode(account);
        subjectParamsForRecovery[1] = abi.encode(oldOwner);
        subjectParamsForRecovery[2] = abi.encode(newOwner);
        subjectParamsForRecovery[3] = abi.encode(recoveryModuleAddress);

        return EmailAuthMsg({
            templateId: emailRecoveryManager.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
    }
}
