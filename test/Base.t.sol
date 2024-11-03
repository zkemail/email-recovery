// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";
import { RhinestoneModuleKit, AccountInstance } from "modulekit/ModuleKit.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

/* solhint-disable gas-custom-errors, custom-errors, reason-string, max-states-count */

interface IEmailRecoveryModule {
    function computeAcceptanceTemplateId(uint256 templateIdx) external pure returns (uint256);

    function computeRecoveryTemplateId(uint256 templateIdx) external pure returns (uint256);

    function handleAcceptance(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external;

    function handleRecovery(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external;

    function completeRecovery(address account, bytes memory completeCalldata) external;
}

enum CommandHandlerType {
    EmailRecoveryCommandHandler,
    AccountHidingRecoveryCommandHandler,
    SafeRecoveryCommandHandler
}

abstract contract BaseTest is RhinestoneModuleKit, Test {
    using Strings for uint256;

    // ZK Email contracts and variables
    address public zkEmailDeployer;
    UserOverrideableDKIMRegistry public dkimRegistry;
    MockGroth16Verifier public verifier;
    EmailAuth public emailAuthImpl;

    OwnableValidator public validator;
    address public validatorAddress;

    // public account and owners
    address public owner1;
    address public owner2;
    address public owner3;
    address public newOwner1;
    address public newOwner2;
    address public newOwner3;
    AccountInstance public instance1;
    AccountInstance public instance2;
    AccountInstance public instance3;
    address public accountAddress1;
    address public accountAddress2;
    address public accountAddress3;
    address public killSwitchAuthorizer;

    // public Account salts
    bytes32 public accountSalt1;
    bytes32 public accountSalt2;
    bytes32 public accountSalt3;

    // public recovery config
    address[] public guardians1;
    address[] public guardians2;
    address[] public guardians3;
    uint256[] public guardianWeights;
    uint256 public totalWeight;
    uint256 public delay;
    uint256 public expiry;
    uint256 public threshold;
    uint256 public templateIdx;
    bytes public isInstalledContext;

    string public selector = "12345";
    string public domainName = "gmail.com";
    bytes32 public publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;
    uint256 public minimumDelay = 12 hours;

    bytes4 public functionSelector;
    bytes public recoveryCalldata;
    bytes public recoveryData;
    bytes32 public recoveryDataHash;

    uint256 public nullifierCount;

    function setUp() public virtual {
        init();

        // create owners
        owner1 = vm.createWallet("owner1").addr;
        owner2 = vm.createWallet("owner2").addr;
        owner3 = vm.createWallet("owner3").addr;
        newOwner1 = vm.createWallet("newOwner1").addr;
        newOwner2 = vm.createWallet("newOwner2").addr;
        newOwner3 = vm.createWallet("newOwner3").addr;

        // Deploy and fund the accounts
        instance1 = makeAccountInstance("account1");
        instance2 = makeAccountInstance("account2");
        instance3 = makeAccountInstance("account3");
        accountAddress1 = instance1.account;
        accountAddress2 = instance2.account;
        accountAddress3 = instance3.account;
        vm.deal(address(instance1.account), 10 ether);
        vm.deal(address(instance2.account), 10 ether);
        vm.deal(address(instance3.account), 10 ether);

        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        accountSalt3 = keccak256(abi.encode("account salt 3"));

        zkEmailDeployer = vm.addr(1);
        killSwitchAuthorizer = vm.addr(2);

        vm.startPrank(zkEmailDeployer);
        uint256 setTimeDelay = 0;
        UserOverrideableDKIMRegistry overrideableDkimImpl = new UserOverrideableDKIMRegistry();
        ERC1967Proxy dkimProxy = new ERC1967Proxy(
            address(overrideableDkimImpl),
            abi.encodeCall(
                overrideableDkimImpl.initialize, (zkEmailDeployer, zkEmailDeployer, setTimeDelay)
            )
        );
        dkimRegistry = UserOverrideableDKIMRegistry(address(dkimProxy));

        dkimRegistry.setDKIMPublicKeyHash(domainName, publicKeyHash, zkEmailDeployer, new bytes(0));

        verifier = new MockGroth16Verifier();
        emailAuthImpl = new EmailAuth();
        vm.stopPrank();

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);

        bytes memory handlerBytecode = getHandlerBytecode();
        setRecoveryData();
        deployModule(handlerBytecode);

        // Compute guardian addresses
        guardians1 = new address[](3);
        guardians1[0] = computeEmailAuthAddress(instance1.account, accountSalt1);
        guardians1[1] = computeEmailAuthAddress(instance1.account, accountSalt2);
        guardians1[2] = computeEmailAuthAddress(instance1.account, accountSalt3);
        guardians2 = new address[](3);
        guardians2[0] = computeEmailAuthAddress(instance2.account, accountSalt1);
        guardians2[1] = computeEmailAuthAddress(instance2.account, accountSalt2);
        guardians2[2] = computeEmailAuthAddress(instance2.account, accountSalt3);
        guardians3 = new address[](3);
        guardians3[0] = computeEmailAuthAddress(instance3.account, accountSalt1);
        guardians3[1] = computeEmailAuthAddress(instance3.account, accountSalt2);
        guardians3[2] = computeEmailAuthAddress(instance3.account, accountSalt3);

        // Set recovery config variables
        guardianWeights = new uint256[](3);
        guardianWeights[0] = 1;
        guardianWeights[1] = 2;
        guardianWeights[2] = 1;
        totalWeight = 4;
        delay = 1 days;
        expiry = 2 weeks;
        threshold = 3;
        templateIdx = 0;
        isInstalledContext = bytes("0");
    }

    /**
     * Return if current account type is safe or not
     */
    function isAccountTypeSafe() public view returns (bool) {
        string memory currentAccountType = vm.envOr("ACCOUNT_TYPE", string(""));
        if (Strings.equal(currentAccountType, "SAFE")) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * Skip the test if the account type is not safe
     */
    function skipIfNotSafeAccountType() public {
        if (isAccountTypeSafe()) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
    }

    /**
     * Returns the commmand handler type
     */
    function getCommandHandlerType() public view returns (CommandHandlerType) {
        return CommandHandlerType(vm.envOr("COMMAND_HANDLER_TYPE", uint256(0)));
    }

    /**
     * Return the command handler bytecode based on the command handler type
     */
    function getHandlerBytecode() public view returns (bytes memory) {
        CommandHandlerType commandHandlerType = getCommandHandlerType();

        if (commandHandlerType == CommandHandlerType.EmailRecoveryCommandHandler) {
            return type(EmailRecoveryCommandHandler).creationCode;
        }
        if (commandHandlerType == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            return type(AccountHidingRecoveryCommandHandler).creationCode;
        }
        if (commandHandlerType == CommandHandlerType.SafeRecoveryCommandHandler) {
            return type(SafeRecoveryCommandHandler).creationCode;
        }

        revert("Invalid command handler type");
    }

    /**
     * Skip the test if command handler type is not the expected type
     */
    function skipIfNotCommandHandlerType(CommandHandlerType commandHandlerType) public {
        if (getCommandHandlerType() == commandHandlerType) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
    }

    /**
     * Skip the test if command handler type is the expected type
     */
    function skipIfCommandHandlerType(CommandHandlerType commandHandlerType) public {
        if (getCommandHandlerType() == commandHandlerType) {
            vm.skip(true);
        } else {
            vm.skip(false);
        }
    }

    function setRecoveryData() public virtual;

    function deployModule(bytes memory handlerBytecode) public virtual;

    function computeEmailAuthAddress(
        address account,
        bytes32 accountSalt
    )
        public
        view
        virtual
        returns (address);

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

    function acceptGuardian(
        address account,
        address guardian,
        address emailRecoveryModule
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getAcceptanceEmailAuthMessage(account, guardian, emailRecoveryModule);
        IEmailRecoveryModule(emailRecoveryModule).handleAcceptance(emailAuthMsg, templateIdx);
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function acceptGuardianWithAccountSalt(
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 optionalAccountSalt
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessageWithAccountSalt(
            account, guardian, emailRecoveryModule, optionalAccountSalt
        );
        IEmailRecoveryModule(emailRecoveryModule).handleAcceptance(emailAuthMsg, templateIdx);
    }

    function getAcceptanceEmailAuthMessage(
        address account,
        address guardian,
        address emailRecoveryModule
    )
        public
        returns (EmailAuthMsg memory)
    {
        return getAcceptanceEmailAuthMessageWithAccountSalt(
            account, guardian, emailRecoveryModule, bytes32(0)
        );
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function getAcceptanceEmailAuthMessageWithAccountSalt(
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 optionalAccountSalt
    )
        public
        virtual
        returns (EmailAuthMsg memory)
    {
        string memory command;
        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            bytes32 accountHash = keccak256(abi.encodePacked(account));
            string memory accountHashString = uint256(accountHash).toHexString(32);
            command = string.concat("Accept guardian request for ", accountHashString);
            commandParamsForAcceptance[0] = abi.encode(accountHashString);
        } else {
            string memory accountString = CommandUtils.addressToChecksumHexString(account);
            command = string.concat("Accept guardian request for ", accountString);
            commandParamsForAcceptance[0] = abi.encode(account);
        }

        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);
        return EmailAuthMsg({
            templateId: IEmailRecoveryModule(emailRecoveryModule).computeAcceptanceTemplateId(
                templateIdx
            ),
            commandParams: commandParamsForAcceptance,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }

    function handleRecovery(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, guardian, _recoveryDataHash, emailRecoveryModule);
        IEmailRecoveryModule(emailRecoveryModule).handleRecovery(emailAuthMsg, templateIdx);
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function handleRecoveryWithAccountSalt(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 optionalAccountSalt
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessageWithAccountSalt(
            account, guardian, _recoveryDataHash, emailRecoveryModule, optionalAccountSalt
        );
        IEmailRecoveryModule(emailRecoveryModule).handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule
    )
        public
        returns (EmailAuthMsg memory)
    {
        return getRecoveryEmailAuthMessageWithAccountSalt(
            account, guardian, _recoveryDataHash, emailRecoveryModule, bytes32(0)
        );
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function getRecoveryEmailAuthMessageWithAccountSalt(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 optionalAccountSalt
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory command;
        bytes[] memory commandParamsForRecovery = new bytes[](2);

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            bytes32 accountHash = keccak256(abi.encodePacked(account));
            string memory accountHashString = uint256(accountHash).toHexString(32);
            string memory recoveryDataHashString = uint256(_recoveryDataHash).toHexString(32);
            string memory commandPart1 = string.concat("Recover account ", accountHashString);
            string memory commandPart2 =
                string.concat(" using recovery hash ", recoveryDataHashString);
            command = string.concat(commandPart1, commandPart2);

            commandParamsForRecovery = new bytes[](2);
            commandParamsForRecovery[0] = abi.encode(accountHashString);
            commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);
        }
        if (getCommandHandlerType() == CommandHandlerType.EmailRecoveryCommandHandler) {
            string memory accountString = CommandUtils.addressToChecksumHexString(account);
            string memory recoveryDataHashString = uint256(_recoveryDataHash).toHexString(32);
            string memory commandPart1 = string.concat("Recover account ", accountString);
            string memory commandPart2 =
                string.concat(" using recovery hash ", recoveryDataHashString);
            command = string.concat(commandPart1, commandPart2);

            commandParamsForRecovery = new bytes[](2);
            commandParamsForRecovery[0] = abi.encode(account);
            commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);
        }
        if (getCommandHandlerType() == CommandHandlerType.SafeRecoveryCommandHandler) {
            string memory accountString = CommandUtils.addressToChecksumHexString(account);
            string memory oldOwnerString = CommandUtils.addressToChecksumHexString(owner1);
            string memory newOwnerString = CommandUtils.addressToChecksumHexString(newOwner1);
            command = string.concat(
                "Recover account ",
                accountString,
                " from old owner ",
                oldOwnerString,
                " to new owner ",
                newOwnerString
            );

            commandParamsForRecovery = new bytes[](3);
            commandParamsForRecovery[0] = abi.encode(accountAddress1);
            commandParamsForRecovery[1] = abi.encode(owner1);
            commandParamsForRecovery[2] = abi.encode(newOwner1);
        }

        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);
        return EmailAuthMsg({
            templateId: IEmailRecoveryModule(emailRecoveryModule).computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
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
            revert("getAccountSaltForGuardian - Invalid account address");
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

        revert("getAccountSaltForGuardian - Invalid guardian address");
    }

    function generateNewNullifier() public returns (bytes32) {
        return keccak256(abi.encode(nullifierCount++));
    }
}
