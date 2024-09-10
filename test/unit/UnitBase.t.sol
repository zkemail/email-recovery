// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    AccountInstance,
    ModuleKitHelpers,
    ModuleKitUserOp
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { ECDSAOwnedDKIMRegistry } from
    "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { CommandUtils } from "ether-email-auth/packages/contracts/src/libraries/CommandUtils.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModuleHarness } from "./UniversalEmailRecoveryModuleHarness.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract UnitBase is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;

    // ZK Email contracts and variables
    address zkEmailDeployer = vm.addr(1);
    ECDSAOwnedDKIMRegistry dkimRegistry;
    MockGroth16Verifier verifier;
    EmailAuth emailAuthImpl;

    EmailRecoveryFactory emailRecoveryFactory;
    EmailRecoveryUniversalFactory emailRecoveryUniversalFactory;
    EmailRecoveryCommandHandler emailRecoveryHandler;
    UniversalEmailRecoveryModuleHarness emailRecoveryModule;

    address recoveryModuleAddress;
    address validatorAddress;

    OwnableValidator validator;
    bytes isInstalledContext;
    bytes4 functionSelector;
    bytes recoveryData;
    bytes32 recoveryDataHash;

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
    uint256 templateIdx;

    // Account salts
    bytes32 accountSalt1;
    bytes32 accountSalt2;
    bytes32 accountSalt3;

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash = 0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;

    function setUp() public virtual {
        init();

        // Create ZK Email contracts
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

        // create owners
        owner = vm.createWallet("owner").addr;
        newOwner = vm.createWallet("newOwner").addr;
        address[] memory owners = new address[](1);
        owners[0] = owner;

        // Deploy handler, manager and module
        emailRecoveryHandler = new EmailRecoveryCommandHandler();
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));
        emailRecoveryUniversalFactory =
            new EmailRecoveryUniversalFactory(address(verifier), address(emailAuthImpl));

        emailRecoveryModule = new UniversalEmailRecoveryModuleHarness(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
        recoveryModuleAddress = address(emailRecoveryModule);

        // Deploy and fund the account
        instance = makeAccountInstance("account");
        accountAddress = instance.account;
        vm.deal(address(instance.account), 10 ether);

        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        accountSalt3 = keccak256(abi.encode("account salt 3"));

        // Compute guardian addresses
        guardian1 = emailRecoveryModule.computeEmailAuthAddress(instance.account, accountSalt1);
        guardian2 = emailRecoveryModule.computeEmailAuthAddress(instance.account, accountSalt2);
        guardian3 = emailRecoveryModule.computeEmailAuthAddress(instance.account, accountSalt3);

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

        // Deploy validator to be recovered
        validator = new OwnableValidator();
        validatorAddress = address(validator);
        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        bytes memory changeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        recoveryData = abi.encode(validatorAddress, changeOwnerCalldata);
        recoveryDataHash = keccak256(recoveryData);

        // Install modules
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner)
        });
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                validatorAddress,
                isInstalledContext,
                functionSelector,
                guardians,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });
    }

    // Helper functions

    function acceptanceCommandTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](5);
        templates[0][0] = "Accept";
        templates[0][1] = "guardian";
        templates[0][2] = "request";
        templates[0][3] = "for";
        templates[0][4] = "{ethAddr}";
        return templates;
    }

    function recoveryCommandTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](7);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "using";
        templates[0][4] = "recovery";
        templates[0][5] = "hash";
        templates[0][6] = "{string}";
        return templates;
    }

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

    function acceptGuardian(bytes32 accountSalt) public {
        string memory accountString = CommandUtils.addressToChecksumHexString(accountAddress);
        string memory command = string.concat("Accept guardian request for ", accountString);

        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(accountAddress);
        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryModule.computeAcceptanceTemplateId(templateIdx),
            commandParams: commandParamsForAcceptance,
            skippedCommandPrefix: 0,
            proof: emailProof
        });

        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function handleRecovery(bytes32 recoveryDataHash, bytes32 accountSalt) public {
        string memory accountString = CommandUtils.addressToChecksumHexString(accountAddress);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        string memory commandPart1 = string.concat("Recover account ", accountString);
        string memory commandPart2 = string.concat(" using recovery hash ", recoveryDataHashString);
        string memory command = string.concat(commandPart1, commandPart2);

        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(accountAddress);
        commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryModule.computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }
}
