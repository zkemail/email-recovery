// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { IntegrationBase } from "../../IntegrationBase.t.sol";

abstract contract OwnableValidatorRecovery_EmailRecoveryModule_Base is IntegrationBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;
    using Strings for address;

    EmailRecoveryFactory emailRecoveryFactory;
    EmailRecoveryCommandHandler emailRecoveryHandler;
    EmailRecoveryModule emailRecoveryModule;

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

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);
        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));

        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));
        emailRecoveryHandler = new EmailRecoveryCommandHandler();

        // Deploy EmailRecoveryManager & EmailRecoveryModule
        bytes32 commandHandlerSalt = bytes32(uint256(0));
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes memory commandHandlerBytecode = type(EmailRecoveryCommandHandler).creationCode;
        (recoveryModuleAddress,) = emailRecoveryFactory.deployEmailRecoveryModule(
            commandHandlerSalt,
            recoveryModuleSalt,
            commandHandlerBytecode,
            address(dkimRegistry),
            validatorAddress,
            functionSelector
        );
        emailRecoveryModule = EmailRecoveryModule(recoveryModuleAddress);

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

        bytes memory recoveryModuleInstallData1 =
            abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry);
        bytes memory recoveryModuleInstallData2 =
            abi.encode(isInstalledContext, guardians2, guardianWeights, threshold, delay, expiry);
        bytes memory recoveryModuleInstallData3 =
            abi.encode(isInstalledContext, guardians3, guardianWeights, threshold, delay, expiry);

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
        string memory command,
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
        emailProof.maskedCommand = command;
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
        view
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
        string memory accountString = CommandUtils.addressToChecksumHexString(account);
        string memory command = string.concat("Accept guardian request for ", accountString);
        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(account);
        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeAcceptanceTemplateId(templateIdx),
            commandParams: commandParamsForAcceptance,
            skippedCommandPrefix: 0,
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
        string memory accountString = CommandUtils.addressToChecksumHexString(account);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
        string memory commandPart1 = string.concat("Recover account ", accountString);
        string memory commandPart2 = string.concat(" using recovery hash ", recoveryDataHashString);

        string memory command = string.concat(commandPart1, commandPart2);
        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(account);
        commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);

        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }
}
