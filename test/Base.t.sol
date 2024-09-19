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
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

/* solhint-disable gas-custom-errors, custom-errors, reason-string, max-states-count */

interface IEmailRecoveryModule {
    function computeAcceptanceTemplateId(uint256 templateIdx) external pure returns (uint256);

    function computeRecoveryTemplateId(uint256 templateIdx) external pure returns (uint256);

    function handleAcceptance(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external;

    function handleRecovery(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external;

    function completeRecovery(address account, bytes memory completeCalldata) external;
}

abstract contract BaseTest is RhinestoneModuleKit, Test {
    using Strings for uint256;

    // ZK Email contracts and variables
    address public zkEmailDeployer;
    ECDSAOwnedDKIMRegistry public dkimRegistry;
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

    string public selector = "12345";
    string public domainName = "gmail.com";
    bytes32 public publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;

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

        vm.startPrank(zkEmailDeployer);
        {
            ECDSAOwnedDKIMRegistry dkimImpl = new ECDSAOwnedDKIMRegistry();
            ERC1967Proxy dkimProxy = new ERC1967Proxy(
                address(dkimImpl),
                abi.encodeCall(dkimImpl.initialize, (zkEmailDeployer, zkEmailDeployer))
            );
            dkimRegistry = ECDSAOwnedDKIMRegistry(address(dkimProxy));
        }
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

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);

        deployModule();

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
        delay = 1 seconds;
        expiry = 2 weeks;
        threshold = 3;
        templateIdx = 0;
    }

    function computeEmailAuthAddress(
        address account,
        bytes32 accountSalt
    )
        public
        view
        virtual
        returns (address);

    function deployModule() public virtual;

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
        bytes32 recoveryDataHash,
        address emailRecoveryModule
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, guardian, recoveryDataHash, emailRecoveryModule);
        IEmailRecoveryModule(emailRecoveryModule).handleRecovery(emailAuthMsg, templateIdx);
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    // FIXME: not used???
    function handleRecoveryWithAccountSalt(
        address account,
        address guardian,
        bytes32 recoveryDataHash,
        address emailRecoveryModule,
        bytes32 optionalAccountSalt
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg = getRecoveryEmailAuthMessageWithAccountSalt(
            account, guardian, recoveryDataHash, emailRecoveryModule, optionalAccountSalt
        );
        IEmailRecoveryModule(emailRecoveryModule).handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        address guardian,
        bytes32 recoveryDataHash,
        address emailRecoveryModule
    )
        public
        returns (EmailAuthMsg memory)
    {
        return getRecoveryEmailAuthMessageWithAccountSalt(
            account, guardian, recoveryDataHash, emailRecoveryModule, bytes32(0)
        );
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function getRecoveryEmailAuthMessageWithAccountSalt(
        address account,
        address guardian,
        bytes32 recoveryDataHash,
        address emailRecoveryModule,
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
