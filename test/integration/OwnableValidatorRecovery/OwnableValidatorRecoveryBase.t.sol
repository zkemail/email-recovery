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
    address validatorAddress;

    OwnableValidator validator;
    bytes isInstalledContext;
    bytes4 functionSelector;
    bytes recoveryCalldata1;
    bytes recoveryCalldata2;
    bytes recoveryCalldata3;
    bytes32 calldataHash1;
    bytes32 calldataHash2;
    bytes32 calldataHash3;

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
        validatorAddress = address(validator);
        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("changeOwner(address,address,address)")));
        recoveryCalldata1 = abi.encodeWithSelector(
            functionSelector, accountAddress1, recoveryModuleAddress, newOwner1
        );
        recoveryCalldata2 = abi.encodeWithSelector(
            functionSelector, accountAddress2, recoveryModuleAddress, newOwner2
        );
        recoveryCalldata2 = abi.encodeWithSelector(
            functionSelector, accountAddress3, recoveryModuleAddress, newOwner3
        );
        calldataHash1 = keccak256(recoveryCalldata1);
        calldataHash2 = keccak256(recoveryCalldata2);
        calldataHash3 = keccak256(recoveryCalldata3);

        // Compute guardian addresses
        guardian1 = emailRecoveryManager.computeEmailAuthAddress(accountSalt1);
        guardian2 = emailRecoveryManager.computeEmailAuthAddress(accountSalt2);
        guardian3 = emailRecoveryManager.computeEmailAuthAddress(accountSalt3);

        guardians = new address[](3);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardians[2] = guardian3;

        bytes memory recoveryModuleInstallData = abi.encode(
            validatorAddress,
            isInstalledContext,
            functionSelector,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );

        // Install modules for account 1
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1, recoveryModuleAddress)
        });
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: recoveryModuleInstallData
        });

        // Install modules for account 2
        instance2.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner2, recoveryModuleAddress)
        });
        instance2.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: recoveryModuleInstallData
        });

        // Install modules for account 3
        instance3.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner3, recoveryModuleAddress)
        });
        instance3.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: recoveryModuleInstallData
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

    function getAccountSaltForGuardian(address guardian) public returns (bytes32) {
        if (guardian == guardian1) {
            return accountSalt1;
        }
        if (guardian == guardian2) {
            return accountSalt2;
        }
        if (guardian == guardian3) {
            return accountSalt3;
        }

        revert("Invalid guardian address");
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
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));
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

    function handleRecovery(address account, address guardian, bytes32 calldataHash) public {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, guardian, calldataHash);
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        address guardian,
        bytes32 calldataHash
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory calldataHashString = uint256(calldataHash).toHexString(32);
        string memory recoveryModuleString =
            SubjectUtils.addressToChecksumHexString(recoveryModuleAddress);
        string memory subjectPart1 = string.concat("Recover account ", accountString);
        string memory subjectPart2 = string.concat(" via recovery module ", recoveryModuleString);
        string memory subjectPart3 = string.concat(" using recovery hash ", calldataHashString);

        string memory subject = string.concat(subjectPart1, subjectPart2, subjectPart3);
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        bytes32 accountSalt = getAccountSaltForGuardian(guardian);

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](3);
        subjectParamsForRecovery[0] = abi.encode(account);
        subjectParamsForRecovery[1] = abi.encode(recoveryModuleAddress);
        subjectParamsForRecovery[2] = abi.encode(calldataHashString);

        return EmailAuthMsg({
            templateId: emailRecoveryManager.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
    }
}
