// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ModuleKitHelpers} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EmailRecoveryFactory} from "src/factories/EmailRecoveryFactory.sol";
import {EmailRecoveryModule} from "src/modules/EmailRecoveryModule.sol";

import {BaseTest} from "../Base.t.sol";

import {EmailProof} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

import {EmailGuardianVerifier} from "src/EmailGuardianVerifier.sol";
import {IGuardianVerifier} from "src/interfaces/IGuardianVerifier.sol";
import {MockGroth16Verifier} from "src/test/MockGroth16Verifier.sol";

import {CommandUtils} from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import {EmailRecoveryCommandHandler} from "src/handlers/EmailRecoveryCommandHandler.sol";
import {AccountHidingRecoveryCommandHandler} from "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import {SafeRecoveryCommandHandler} from "src/handlers/SafeRecoveryCommandHandler.sol";

import {UserOverrideableDKIMRegistry} from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

interface IEmailRecoveryModule {
    function handleAcceptance(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData,
        IGuardianVerifier.ProofData memory proofData
    ) external;

    function handleRecovery(
        address guardian,
        address account,
        bytes32 accountSalt,
        bytes32 recoveryDataHash,
        IGuardianVerifier.ProofData memory proofData
    ) external;

    function completeRecovery(
        address account,
        bytes memory completeCalldata
    ) external;
}

enum CommandHandlerType {
    EmailRecoveryCommandHandler,
    AccountHidingRecoveryCommandHandler,
    SafeRecoveryCommandHandler
}

/**
 * Base setup for Email Guardian verifier
 */
abstract contract OwnableValidatorRecovery_AbstractedRecoveryModule_Base is
    BaseTest
{
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    UserOverrideableDKIMRegistry public dkimRegistry;
    MockGroth16Verifier public verifier;

    address public commandHandler;

    EmailRecoveryFactory public emailRecoveryFactory;
    address public commandHandlerAddress;
    EmailRecoveryModule public emailRecoveryModule;

    address public emailRecoveryModuleAddress;

    bytes public recoveryData1;
    bytes public recoveryData2;
    bytes public recoveryData3;
    bytes32 public recoveryDataHash1;
    bytes32 public recoveryDataHash2;
    bytes32 public recoveryDataHash3;

    address public emailGuardianVerifierImplementation;
    bytes public emailGuardianVerifierInitData;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(zkEmailDeployer);
        uint256 setTimeDelay = 0;
        UserOverrideableDKIMRegistry overrideableDkimImpl = new UserOverrideableDKIMRegistry();
        ERC1967Proxy dkimProxy = new ERC1967Proxy(
            address(overrideableDkimImpl),
            abi.encodeCall(
                overrideableDkimImpl.initialize,
                (zkEmailDeployer, zkEmailDeployer, setTimeDelay)
            )
        );
        dkimRegistry = UserOverrideableDKIMRegistry(address(dkimProxy));

        dkimRegistry.setDKIMPublicKeyHash(
            domainName,
            publicKeyHash,
            zkEmailDeployer,
            new bytes(0)
        );
        verifier = new MockGroth16Verifier();

        // Deploying command handler
        bytes memory handlerBytecode = getHandlerBytecode();
        bytes32 commandHandlerSalt = bytes32(uint256(0));
        commandHandler = Create2.deploy(0, commandHandlerSalt, handlerBytecode);

        vm.stopPrank();

        // Setup for the email guardian verifier
        bytes memory initData = abi.encode(
            address(dkimRegistry),
            address(verifier),
            address(commandHandler)
        );
        emailGuardianVerifierInitData = initData;

        // Deploy the email guardian verifier
        emailGuardianVerifierImplementation = address(
            new EmailGuardianVerifier()
        );

        guardians1 = new address[](3);
        guardians1[0] = computeGuardianVerifierAuthAddress(
            emailGuardianVerifierImplementation,
            instance1.account,
            accountSalt1,
            emailGuardianVerifierInitData
        );
        guardians1[1] = computeGuardianVerifierAuthAddress(
            emailGuardianVerifierImplementation,
            instance1.account,
            accountSalt2,
            emailGuardianVerifierInitData
        );
        guardians1[2] = computeGuardianVerifierAuthAddress(
            emailGuardianVerifierImplementation,
            instance1.account,
            accountSalt3,
            emailGuardianVerifierInitData
        );

        // INITIAL SETUP
        bytes memory changeOwnerCalldata1 = abi.encodeWithSelector(
            functionSelector,
            newOwner1
        );
        bytes memory changeOwnerCalldata2 = abi.encodeWithSelector(
            functionSelector,
            newOwner2
        );
        bytes memory changeOwnerCalldata3 = abi.encodeWithSelector(
            functionSelector,
            newOwner3
        );
        recoveryData1 = abi.encode(validatorAddress, changeOwnerCalldata1);
        recoveryData2 = abi.encode(validatorAddress, changeOwnerCalldata2);
        recoveryData3 = abi.encode(validatorAddress, changeOwnerCalldata3);
        recoveryDataHash1 = keccak256(recoveryData1);
        recoveryDataHash2 = keccak256(recoveryData2);
        recoveryDataHash3 = keccak256(recoveryData3);

        bytes memory recoveryModuleInstallData1 = abi.encode(
            isInstalledContext,
            guardians1,
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
            module: emailRecoveryModuleAddress,
            data: recoveryModuleInstallData1
        });
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

        if (
            commandHandlerType == CommandHandlerType.EmailRecoveryCommandHandler
        ) {
            return type(EmailRecoveryCommandHandler).creationCode;
        }
        if (
            commandHandlerType ==
            CommandHandlerType.AccountHidingRecoveryCommandHandler
        ) {
            return type(AccountHidingRecoveryCommandHandler).creationCode;
        }
        if (
            commandHandlerType == CommandHandlerType.SafeRecoveryCommandHandler
        ) {
            return type(SafeRecoveryCommandHandler).creationCode;
        }

        revert("Invalid command handler type");
    }

    /**
     * Skip the test if command handler type is not the expected type
     */
    function skipIfNotCommandHandlerType(
        CommandHandlerType commandHandlerType
    ) public {
        if (getCommandHandlerType() == commandHandlerType) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
    }

    /**
     * Skip the test if command handler type is the expected type
     */
    function skipIfCommandHandlerType(
        CommandHandlerType commandHandlerType
    ) public {
        if (getCommandHandlerType() == commandHandlerType) {
            vm.skip(true);
        } else {
            vm.skip(false);
        }
    }

    // Helper functions
    function computeGuardianVerifierAuthAddress(
        address guardianVerifierImplementation,
        address account,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) public view override returns (address) {
        return
            emailRecoveryModule.computeGuardianVerifierAddress(
                guardianVerifierImplementation,
                account,
                accountSalt,
                verifierInitData
            );
    }

    // Helper functions
    function deployModule() public override {
        emailRecoveryFactory = new EmailRecoveryFactory();

        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        emailRecoveryModuleAddress = emailRecoveryFactory
            .deployEmailRecoveryModule(
                recoveryModuleSalt,
                minimumDelay,
                killSwitchAuthorizer,
                validatorAddress,
                functionSelector
            );
        emailRecoveryModule = EmailRecoveryModule(emailRecoveryModuleAddress);

        if (
            getCommandHandlerType() ==
            CommandHandlerType.AccountHidingRecoveryCommandHandler
        ) {
            AccountHidingRecoveryCommandHandler(commandHandlerAddress)
                .storeAccountHash(accountAddress1);
            AccountHidingRecoveryCommandHandler(commandHandlerAddress)
                .storeAccountHash(accountAddress2);
            AccountHidingRecoveryCommandHandler(commandHandlerAddress)
                .storeAccountHash(accountAddress3);
        }
    }

    // Helper functions
    function setRecoveryData() public override {
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        recoveryCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        recoveryData = abi.encode(validatorAddress, recoveryCalldata);
        recoveryDataHash = keccak256(recoveryData);
    }

    function generateMockEmailProof(
        string memory command,
        bytes32 nullifier,
        bytes32 accountSalt
    ) public view returns (EmailProof memory) {
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
        address guardianVerifierImplementation,
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) public {
        EmailGuardianVerifier.ProofData
            memory proofData = getAcceptanceEmailProofData(
                account,
                guardian,
                emailRecoveryModule,
                accountSalt
            );
        IEmailRecoveryModule(emailRecoveryModule).handleAcceptance(
            guardianVerifierImplementation,
            account,
            accountSalt,
            verifierInitData,
            proofData
        );
    }

    function getAcceptanceEmailProofData(
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public returns (IGuardianVerifier.ProofData memory proofData) {
        string memory command;
        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        if (
            getCommandHandlerType() ==
            CommandHandlerType.AccountHidingRecoveryCommandHandler
        ) {
            bytes32 accountHash = keccak256(abi.encodePacked(account));
            string memory accountHashString = uint256(accountHash).toHexString(
                32
            );
            command = string.concat(
                "Accept guardian request for ",
                accountHashString
            );
            commandParamsForAcceptance[0] = abi.encode(accountHashString);
        } else {
            string memory accountString = CommandUtils
                .addressToChecksumHexString(account);
            command = string.concat(
                "Accept guardian request for ",
                accountString
            );
            commandParamsForAcceptance[0] = abi.encode(account);
        }

        bytes32 nullifier = generateNewNullifier();

        EmailProof memory emailProof = generateMockEmailProof(
            command,
            nullifier,
            accountSalt
        );

        EmailGuardianVerifier.EmailData memory emailData = EmailGuardianVerifier
            .EmailData({
                templateIdx: 0,
                commandParams: commandParamsForAcceptance,
                skippedCommandPrefix: 0,
                domainName: emailProof.domainName,
                timestamp: emailProof.timestamp,
                maskedCommand: emailProof.maskedCommand,
                accountSalt: accountSalt,
                isCodeExist: emailProof.isCodeExist,
                isRecovery: false, // Acceptance
                recoveryDataHash: bytes32(0) // Not used in acceptance
            });

        bytes32[] memory acceptancePublicInputs = new bytes32[](2);
        acceptancePublicInputs[0] = emailProof.publicKeyHash; // publicKeyHash
        acceptancePublicInputs[1] = emailProof.emailNullifier; // emailNullifier

        proofData = IGuardianVerifier.ProofData({
            proof: emailProof.proof,
            publicInputs: acceptancePublicInputs,
            data: abi.encode(emailData)
        });
    }

    function handleRecovery(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public {
        EmailGuardianVerifier.ProofData
            memory emailProofData = getRecoveryEmailProofData(
                account,
                guardian,
                _recoveryDataHash,
                emailRecoveryModule,
                accountSalt
            );
        IEmailRecoveryModule(emailRecoveryModule).handleRecovery(
            guardian,
            account,
            accountSalt,
            _recoveryDataHash,
            emailProofData
        );
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function getRecoveryEmailProofData(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public returns (IGuardianVerifier.ProofData memory proofData) {
        string memory command;
        bytes[] memory commandParamsForRecovery = new bytes[](2);

        if (
            getCommandHandlerType() ==
            CommandHandlerType.AccountHidingRecoveryCommandHandler
        ) {
            bytes32 accountHash = keccak256(abi.encodePacked(account));
            string memory accountHashString = uint256(accountHash).toHexString(
                32
            );
            string memory recoveryDataHashString = uint256(_recoveryDataHash)
                .toHexString(32);
            string memory commandPart1 = string.concat(
                "Recover account ",
                accountHashString
            );
            string memory commandPart2 = string.concat(
                " using recovery hash ",
                recoveryDataHashString
            );
            command = string.concat(commandPart1, commandPart2);

            commandParamsForRecovery = new bytes[](2);
            commandParamsForRecovery[0] = abi.encode(accountHashString);
            commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);
        }
        if (
            getCommandHandlerType() ==
            CommandHandlerType.EmailRecoveryCommandHandler
        ) {
            string memory accountString = CommandUtils
                .addressToChecksumHexString(account);
            string memory recoveryDataHashString = uint256(_recoveryDataHash)
                .toHexString(32);
            string memory commandPart1 = string.concat(
                "Recover account ",
                accountString
            );
            string memory commandPart2 = string.concat(
                " using recovery hash ",
                recoveryDataHashString
            );
            command = string.concat(commandPart1, commandPart2);

            commandParamsForRecovery = new bytes[](2);
            commandParamsForRecovery[0] = abi.encode(account);
            commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);
        }
        if (
            getCommandHandlerType() ==
            CommandHandlerType.SafeRecoveryCommandHandler
        ) {
            string memory accountString = CommandUtils
                .addressToChecksumHexString(account);
            string memory oldOwnerString = CommandUtils
                .addressToChecksumHexString(owner1);
            string memory newOwnerString = CommandUtils
                .addressToChecksumHexString(newOwner1);
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

        EmailProof memory emailProof = generateMockEmailProof(
            command,
            nullifier,
            accountSalt
        );

        EmailGuardianVerifier.EmailData memory emailData = EmailGuardianVerifier
            .EmailData({
                templateIdx: 0,
                commandParams: commandParamsForRecovery,
                skippedCommandPrefix: 0,
                domainName: emailProof.domainName,
                timestamp: emailProof.timestamp,
                maskedCommand: emailProof.maskedCommand,
                accountSalt: accountSalt,
                isCodeExist: emailProof.isCodeExist,
                isRecovery: true, // Acceptance
                recoveryDataHash: _recoveryDataHash
            });

        bytes32[] memory acceptancePublicInputs = new bytes32[](2);
        acceptancePublicInputs[0] = emailProof.publicKeyHash; // publicKeyHash
        acceptancePublicInputs[1] = emailProof.emailNullifier; // emailNullifier

        proofData = IGuardianVerifier.ProofData({
            proof: emailProof.proof,
            publicInputs: acceptancePublicInputs,
            data: abi.encode(emailData)
        });
    }
}
