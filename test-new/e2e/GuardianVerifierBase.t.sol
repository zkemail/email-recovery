// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ModuleKitHelpers} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EmailRecoveryFactory} from "src/factories/EmailRecoveryFactory.sol";
import {EmailRecoveryModule} from "src/modules/EmailRecoveryModule.sol";

import {BaseTest} from "../Base.t.sol";

import {EmailProof} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

// Email Guardian verifier
import {EmailGuardianVerifier} from "src/EmailGuardianVerifier.sol";
import {IGuardianVerifier} from "src/interfaces/IGuardianVerifier.sol";
import {MockGroth16Verifier} from "src/test/MockGroth16Verifier.sol";

// JWT Guardian verifier
import {MockJwtVerifier} from "src/test/MockJwtVerifier.sol";
import {JwtGuardianVerifier} from "src/JwtGuardianVerifier.sol";

// Email.Nr Guardian verifier
import {EmailNrGuardianVerifier} from "src/EmailNrGuardianVerifier.sol";
import {HonkVerifier} from "src/test/HonkVerifier.sol";

// Command handler
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

enum GuardianType {
    EmailGuardian,
    EmailNrGuardian,
    JwtGuardian
}

/**
 * Base setup for Email Guardian verifier
 */
abstract contract OwnableValidatorRecovery_AbstractedRecoveryModule_Base is
    BaseTest
{
    struct NoirProof {
        bytes proof;
    }

    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    // UserOverrideableDKIMRegistry public dkimRegistry;
    // MockGroth16Verifier public verifier;

    // address public commandHandler;

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

    address public jwtGuardianVerifierImplementation;
    bytes public jwtGuardianVerifierInitData;

    address public emailGuardianNrVerifierImplementation;
    bytes public emailGuardianNrVerifierInitData;

    uint256 public templateIdx;

    function setUp() public virtual override {
        super.setUp();

        templateIdx = 0;

        vm.startPrank(zkEmailDeployer);

        // Setup for Email guardian verifier
        uint256 setTimeDelay = 0;
        UserOverrideableDKIMRegistry overrideableDkimImpl = new UserOverrideableDKIMRegistry();
        ERC1967Proxy dkimProxy = new ERC1967Proxy(
            address(overrideableDkimImpl),
            abi.encodeCall(
                overrideableDkimImpl.initialize,
                (zkEmailDeployer, zkEmailDeployer, setTimeDelay)
            )
        );
        UserOverrideableDKIMRegistry dkimRegistry = UserOverrideableDKIMRegistry(
                address(dkimProxy)
            );

        dkimRegistry.setDKIMPublicKeyHash(
            domainName,
            publicKeyHash,
            zkEmailDeployer,
            new bytes(0)
        );
        MockGroth16Verifier emailVerifier = new MockGroth16Verifier();

        // Deploying command handler
        bytes memory handlerBytecode = getHandlerBytecode();
        bytes32 commandHandlerSalt = bytes32(uint256(0));
        address commandHandler = Create2.deploy(
            0,
            commandHandlerSalt,
            handlerBytecode
        );

        // Setup for JWT verifier
        MockJwtVerifier jwtVerifier = new MockJwtVerifier();

        // Setup for EmailNr verifier
        HonkVerifier emailNrVerifier = new HonkVerifier();

        vm.stopPrank();

        // Setup for the email guardian verifier
        emailGuardianVerifierInitData = abi.encode(
            address(dkimRegistry),
            address(emailVerifier),
            address(commandHandler)
        );

        // Deploy the email guardian verifier
        emailGuardianVerifierImplementation = address(
            new EmailGuardianVerifier()
        );

        // Setup for the jwt guardian verifier
        jwtGuardianVerifierInitData = abi.encode(
            address(dkimRegistry),
            address(jwtVerifier)
        );

        // Deploy the jwt guardian verifier
        jwtGuardianVerifierImplementation = address(new JwtGuardianVerifier());

        // Setup for the email nr guardian verifier
        emailGuardianNrVerifierInitData = abi.encode(
            address(dkimRegistry),
            address(emailNrVerifier)
        );

        // Deploy the email nr guardian verifier
        emailGuardianNrVerifierImplementation = address(
            new EmailNrGuardianVerifier()
        );

        guardians1 = new address[](3);

        // Email guardian
        guardians1[0] = computeGuardianVerifierAuthAddress(
            emailGuardianVerifierImplementation,
            instance1.account,
            accountSalt1,
            emailGuardianVerifierInitData
        );

        // EmailNr guardian
        guardians1[1] = computeGuardianVerifierAuthAddress(
            emailGuardianNrVerifierImplementation,
            instance1.account,
            accountSalt2,
            emailGuardianNrVerifierInitData
        );

        // JWT guardian
        guardians1[2] = computeGuardianVerifierAuthAddress(
            jwtGuardianVerifierImplementation,
            instance1.account,
            accountSalt3,
            jwtGuardianVerifierInitData
        );

        // INITIAL SETUP
        bytes memory changeOwnerCalldata1 = abi.encodeWithSelector(
            functionSelector,
            newOwner1
        );

        recoveryData1 = abi.encode(validatorAddress, changeOwnerCalldata1);
        recoveryDataHash1 = keccak256(recoveryData1);

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

    function generateMockJwtProof(
        string memory command,
        bytes32 nullifier,
        bytes32 accountSalt
    ) public view returns (EmailProof memory) {
        EmailProof memory emailProof;
        emailProof
            .domainName = "ee193d4647ab4a3585aa9b2b3b484a87aa68bb42|https://accounts.google.com|397234807794-fh6mhl0jppgtt0ak5cgikhlesbe8f7si.apps.googleusercontent.com";

        // TODO: Public key hash is not derived from decoded jwt
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
        GuardianType guardianType,
        address guardianVerifierImplementation,
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) public {
        IGuardianVerifier.ProofData
            memory proofData = getAcceptanceEmailProofData(
                account,
                guardian,
                emailRecoveryModule,
                accountSalt
            );

        if (guardianType == GuardianType.JwtGuardian) {
            proofData = getAcceptanceJwtProofData(
                account,
                guardian,
                emailRecoveryModule,
                accountSalt
            );
        } else if (guardianType == GuardianType.EmailNrGuardian) {
            proofData = getAcceptanceEmailNrProofData(
                account,
                guardian,
                emailRecoveryModule,
                accountSalt
            );
        }

        IEmailRecoveryModule(emailRecoveryModule).handleAcceptance(
            guardianVerifierImplementation,
            account,
            accountSalt,
            verifierInitData,
            proofData
        );
    }

    function getAcceptanceJwtProofData(
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public returns (IGuardianVerifier.ProofData memory proofData) {
        bytes32 nullifier = generateNewNullifier();

        string memory command = "Accept being a guardian for account 0x..123";

        EmailProof memory jwtProof = generateMockJwtProof(
            command,
            nullifier,
            accountSalt
        );

        JwtGuardianVerifier.JwtData memory jwtData = JwtGuardianVerifier
            .JwtData({
                domainName: jwtProof.domainName,
                timestamp: jwtProof.timestamp,
                maskedCommand: jwtProof.maskedCommand,
                accountSalt: accountSalt,
                isCodeExist: jwtProof.isCodeExist,
                isRecovery: false
            });

        bytes32[] memory acceptancePublicInputs = new bytes32[](2);
        acceptancePublicInputs[0] = jwtProof.publicKeyHash;
        acceptancePublicInputs[1] = jwtProof.emailNullifier;

        proofData = IGuardianVerifier.ProofData({
            proof: jwtProof.proof,
            publicInputs: acceptancePublicInputs,
            data: abi.encode(jwtData)
        });
    }

    // Email based acceptance proof
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
                isRecovery: false // Acceptance
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

    function getAcceptanceEmailNrProofData(
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public returns (IGuardianVerifier.ProofData memory proofData) {
        EmailProof memory emailProof;
        emailProof.domainName = "gmail.com";
        emailProof.timestamp = block.timestamp;
        emailProof.maskedCommand = "";
        emailProof.accountSalt = accountSalt;
        emailProof.isCodeExist = true;

        string memory proofFile = vm.readFile(
            string.concat(
                vm.projectRoot(),
                "/test-new/EmailNrGuardianVerifier/acceptance-proof.json"
            )
        );

        NoirProof memory proof = abi.decode(
            vm.parseJson(proofFile),
            (NoirProof)
        );

        emailProof.proof = proof.proof;
        // emailProof.publicKeyHash = proof.pubkey;
        // emailProof.emailNullifier = proof.nullifier;

        emailProof
            .publicKeyHash = 0x1087f6b1ab2993e76027710b0cd25085b759aaffda8f8aefe04eeaa4df14fccf;
        emailProof
            .emailNullifier = 0x04fab54ce5298aff53698f77bf1426d5768c0cc9657b77bd388145a89ae5a89e;

        EmailNrGuardianVerifier.EmailData
            memory emailData = EmailNrGuardianVerifier.EmailData({
                domainName: emailProof.domainName,
                timestamp: emailProof.timestamp,
                accountSalt: accountSalt
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
        GuardianType guardianType,
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public {
        IGuardianVerifier.ProofData
            memory proofData = getRecoveryEmailProofData(
                account,
                guardian,
                _recoveryDataHash,
                emailRecoveryModule,
                accountSalt
            );

        if (guardianType == GuardianType.JwtGuardian) {
            proofData = getRecoveryJwtProofData(
                account,
                guardian,
                _recoveryDataHash,
                emailRecoveryModule,
                accountSalt
            );
        } else if (guardianType == GuardianType.EmailNrGuardian) {
            proofData = getRecoveryEmailNrProofData(
                account,
                guardian,
                _recoveryDataHash,
                emailRecoveryModule,
                accountSalt
            );
        }

        IEmailRecoveryModule(emailRecoveryModule).handleRecovery(
            guardian,
            account,
            accountSalt,
            _recoveryDataHash,
            proofData
        );
    }

    // WithAccountSalt variation - used for creating incorrect recovery setups
    function getRecoveryJwtProofData(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public returns (IGuardianVerifier.ProofData memory proofData) {
        bytes32 nullifier = generateNewNullifier();

        string
            memory command = "Recver account 0x..123 using recovery hash 0x..123";

        EmailProof memory jwtProof = generateMockJwtProof(
            command,
            nullifier,
            accountSalt
        );

        JwtGuardianVerifier.JwtData memory jwtData = JwtGuardianVerifier
            .JwtData({
                domainName: jwtProof.domainName,
                timestamp: jwtProof.timestamp,
                maskedCommand: jwtProof.maskedCommand,
                accountSalt: accountSalt,
                isCodeExist: jwtProof.isCodeExist,
                isRecovery: true
            });

        bytes32[] memory acceptancePublicInputs = new bytes32[](2);
        acceptancePublicInputs[0] = jwtProof.publicKeyHash;
        acceptancePublicInputs[1] = jwtProof.emailNullifier;

        proofData = IGuardianVerifier.ProofData({
            proof: jwtProof.proof,
            publicInputs: acceptancePublicInputs,
            data: abi.encode(jwtData)
        });
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
                isRecovery: true // Acceptance
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

    function getRecoveryEmailNrProofData(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public returns (IGuardianVerifier.ProofData memory proofData) {
        EmailProof memory emailProof;
        emailProof.domainName = "gmail.com";
        emailProof.timestamp = block.timestamp;
        emailProof.maskedCommand = "";
        emailProof.accountSalt = accountSalt;
        emailProof.isCodeExist = true;

        string memory proofFile = vm.readFile(
            string.concat(
                vm.projectRoot(),
                "/test-new/EmailNrGuardianVerifier/recovery-proof.json"
            )
        );

        NoirProof memory proof = abi.decode(
            vm.parseJson(proofFile),
            (NoirProof)
        );

        emailProof.proof = proof.proof;
        // emailProof.publicKeyHash = proof.pubkey;
        // emailProof.emailNullifier = proof.nullifier;

        emailProof
            .publicKeyHash = 0x1087f6b1ab2993e76027710b0cd25085b759aaffda8f8aefe04eeaa4df14fccf;
        emailProof
            .emailNullifier = 0x12a412c72a2ec60e1f12860d8ebb3b85fdea87f9ed5cfd805f11f1e619716c29;

        EmailNrGuardianVerifier.EmailData
            memory emailData = EmailNrGuardianVerifier.EmailData({
                domainName: emailProof.domainName,
                timestamp: emailProof.timestamp,
                accountSalt: accountSalt
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
