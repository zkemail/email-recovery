// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SubjectUtils } from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModuleHarness } from
    "../../../unit/UniversalEmailRecoveryModuleHarness.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { IntegrationBase } from "../../IntegrationBase.t.sol";

abstract contract OwnableValidatorRecovery_UniversalEmailRecoveryModule_Base is IntegrationBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;
    using Strings for address;

    EmailRecoveryUniversalFactory emailRecoveryFactory;
    EmailRecoverySubjectHandler emailRecoveryHandler;
    UniversalEmailRecoveryModuleHarness emailRecoveryModule;

    address recoveryModuleAddress;
    address validatorAddress;

    OwnableValidator validator;
    bytes isInstalledContext;
    bytes4 functionSelector;
    bytes recoveryData1;
    bytes recoveryData2;
    bytes recoveryData3;
    bytes32 recoveryDataHash1;
    bytes32 recoveryDataHash2;
    bytes32 recoveryDataHash3;

    uint256 nullifierCount;

    function setUp() public virtual override {
        super.setUp();

        emailRecoveryFactory =
            new EmailRecoveryUniversalFactory(address(verifier), address(emailAuthImpl));
        emailRecoveryHandler = new EmailRecoverySubjectHandler();

        // Deploy EmailRecoveryManager & UniversalEmailRecoveryModule
        bytes32 subjectHandlerSalt = bytes32(uint256(0));
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes memory subjectHandlerBytecode = type(EmailRecoverySubjectHandler).creationCode;
        emailRecoveryModule = new UniversalEmailRecoveryModuleHarness(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
        recoveryModuleAddress = address(emailRecoveryModule);

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);
        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        bytes memory changeOwnerCalldata1 = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory changeOwnerCalldata2 = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory changeOwnerCalldata3 = abi.encodeWithSelector(functionSelector, newOwner3);
        recoveryData1 = abi.encode(validatorAddress, changeOwnerCalldata1);
        recoveryData2 = abi.encode(validatorAddress, changeOwnerCalldata2);
        recoveryData3 = abi.encode(validatorAddress, changeOwnerCalldata3);
        recoveryDataHash1 = keccak256(recoveryData1);
        recoveryDataHash2 = keccak256(recoveryData2);
        recoveryDataHash3 = keccak256(recoveryData3);

        // Compute guardian addresses
        guardians1 = new address[](3);
        guardians1[0] = emailRecoveryModule.computeEmailAuthAddress(instance1.account, accountSalt1);
        guardians1[1] = emailRecoveryModule.computeEmailAuthAddress(instance1.account, accountSalt2);
        guardians1[2] = emailRecoveryModule.computeEmailAuthAddress(instance1.account, accountSalt3);
        guardians2 = new address[](3);
        guardians2[0] = emailRecoveryModule.computeEmailAuthAddress(instance2.account, accountSalt1);
        guardians2[1] = emailRecoveryModule.computeEmailAuthAddress(instance2.account, accountSalt2);
        guardians2[2] = emailRecoveryModule.computeEmailAuthAddress(instance2.account, accountSalt3);
        guardians3 = new address[](3);
        guardians3[0] = emailRecoveryModule.computeEmailAuthAddress(instance3.account, accountSalt1);
        guardians3[1] = emailRecoveryModule.computeEmailAuthAddress(instance3.account, accountSalt2);
        guardians3[2] = emailRecoveryModule.computeEmailAuthAddress(instance3.account, accountSalt3);

        bytes memory recoveryModuleInstallData1 = abi.encode(
            validatorAddress,
            isInstalledContext,
            functionSelector,
            guardians1,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        bytes memory recoveryModuleInstallData2 = abi.encode(
            validatorAddress,
            isInstalledContext,
            functionSelector,
            guardians2,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        bytes memory recoveryModuleInstallData3 = abi.encode(
            validatorAddress,
            isInstalledContext,
            functionSelector,
            guardians3,
            guardianWeights,
            threshold,
            delay,
            expiry
        );

        // Install modules for account 1
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1)
        });
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: recoveryModuleInstallData1
        });

        // Install modules for account 2
        instance2.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner2)
        });
        instance2.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: recoveryModuleInstallData2
        });

        // Install modules for account 3
        instance3.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner3)
        });
        instance3.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: recoveryModuleInstallData3
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

    function getAccountSaltForGuardian(
        address account,
        address guardian
    )
        public
        returns (bytes32)
    {
        address[] memory guardians;
        if (account == instance1.account) {
            guardians = guardians1;
        } else if (account == instance2.account) {
            guardians = guardians2;
        } else if (account == instance3.account) {
            guardians = guardians3;
        } else {
            revert("Invalid account address");
        }
        if (guardian == guardians[0]) {
            return accountSalt1;
        }
        if (guardian == guardians[1]) {
            return accountSalt2;
        }
        if (guardian == guardians[2]) {
            return accountSalt3;
        }

        revert("Invalid guardian address");
    }

    function generateNewNullifier() public returns (bytes32) {
        return keccak256(abi.encode(nullifierCount++));
    }

    function acceptGuardian(address account, address guardian) public {
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(account, guardian);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function acceptGuardianWithAccountSalt(
        address account,
        address guardian,
        bytes32 optionalAccountSalt
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessageWithAccountSalt(account, guardian, optionalAccountSalt);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function getAcceptanceEmailAuthMessage(
        address account,
        address guardian
    )
        public
        returns (EmailAuthMsg memory)
    {
        return getAcceptanceEmailAuthMessageWithAccountSalt(account, guardian, bytes32(0));
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function getAcceptanceEmailAuthMessageWithAccountSalt(
        address account,
        address guardian,
        bytes32 optionalAccountSalt
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory subject = string.concat("Accept guardian request for ", accountString);
        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(account);
        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeAcceptanceTemplateId(templateIdx),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
    }

    function handleRecovery(address account, address guardian, bytes32 recoveryDataHash) public {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, guardian, recoveryDataHash);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function handleRecoveryWithAccountSalt(
        address account,
        address guardian,
        bytes32 recoveryDataHash,
        bytes32 optionalAccountSalt
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessageWithAccountSalt(
            account, guardian, recoveryDataHash, optionalAccountSalt
        );
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        address guardian,
        bytes32 recoveryDataHash
    )
        public
        returns (EmailAuthMsg memory)
    {
        return getRecoveryEmailAuthMessageWithAccountSalt(
            account, guardian, recoveryDataHash, bytes32(0)
        );
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function getRecoveryEmailAuthMessageWithAccountSalt(
        address account,
        address guardian,
        bytes32 recoveryDataHash,
        bytes32 optionalAccountSalt
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
        string memory recoveryModuleString =
            SubjectUtils.addressToChecksumHexString(recoveryModuleAddress);
        string memory subjectPart1 = string.concat("Recover account ", accountString);
        string memory subjectPart2 = string.concat(" via recovery module ", recoveryModuleString);
        string memory subjectPart3 = string.concat(" using recovery hash ", recoveryDataHashString);

        string memory subject = string.concat(subjectPart1, subjectPart2, subjectPart3);
        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](3);
        subjectParamsForRecovery[0] = abi.encode(account);
        subjectParamsForRecovery[1] = abi.encode(recoveryModuleAddress);
        subjectParamsForRecovery[2] = abi.encode(recoveryDataHashString);

        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
    }
}
