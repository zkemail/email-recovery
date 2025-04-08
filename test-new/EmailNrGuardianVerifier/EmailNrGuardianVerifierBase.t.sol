// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ModuleKitHelpers} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EmailRecoveryFactory} from "src/factories/EmailRecoveryFactory.sol";
import {EmailRecoveryModule} from "src/modules/EmailRecoveryModule.sol";

import {BaseTest} from "../Base.t.sol";

import {EmailProof} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

import {EmailNrGuardianVerifier} from "src/EmailNrGuardianVerifier.sol";
import {IGuardianVerifier} from "src/interfaces/IGuardianVerifier.sol";
import {HonkVerifier} from "src/test/HonkVerifier.sol";

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
abstract contract OwnableValidatorRecovery_EmailNrGuardianVerifier_Base is
    BaseTest
{
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    UserOverrideableDKIMRegistry public dkimRegistry;
    HonkVerifier public verifier;

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

        verifier = new HonkVerifier();

        vm.stopPrank();

        // Setup for the email guardian verifier
        bytes memory initData = abi.encode(
            address(dkimRegistry),
            address(verifier)
        );
        emailGuardianVerifierInitData = initData;

        // Deploy the email guardian verifier
        emailGuardianVerifierImplementation = address(
            new EmailNrGuardianVerifier()
        );

        // guardians1 = new address[](3);
        guardians1 = new address[](1);
        guardians1[0] = computeGuardianVerifierAuthAddress(
            emailGuardianVerifierImplementation,
            instance1.account,
            accountSalt1,
            emailGuardianVerifierInitData
        );
        // guardians1[1] = computeGuardianVerifierAuthAddress(
        //     emailGuardianVerifierImplementation,
        //     instance1.account,
        //     accountSalt2,
        //     emailGuardianVerifierInitData
        // );
        // guardians1[2] = computeGuardianVerifierAuthAddress(
        //     emailGuardianVerifierImplementation,
        //     instance1.account,
        //     accountSalt3,
        //     emailGuardianVerifierInitData
        // );

        // INITIAL SETUP
        bytes memory changeOwnerCalldata1 = abi.encodeWithSelector(
            functionSelector,
            newOwner1
        );

        recoveryData1 = abi.encode(validatorAddress, changeOwnerCalldata1);
        recoveryDataHash1 = keccak256(recoveryData1);

        guardianWeights = new uint256[](1);
        guardianWeights[0] = 1;
        totalWeight = 1;
        threshold = 1;

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
        // Deploy the email recovery factory after removing email guardian verifier related logic
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

    // bytes32 pubkey;
    // bytes32 nullifier;
    struct NoirProof {
        bytes proof;
    }

    function acceptGuardian(
        address guardianVerifierImplementation,
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 accountSalt,
        bytes memory verifierInitData
    ) public {
        EmailNrGuardianVerifier.ProofData
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

        emailProof
            .publicKeyHash = 0x1087f6b1ab2993e76027710b0cd25085b759aaffda8f8aefe04eeaa4df14fccf;
        emailProof
            .emailNullifier = 0x04fab54ce5298aff53698f77bf1426d5768c0cc9657b77bd388145a89ae5a89e;

        EmailNrGuardianVerifier.EmailData
            memory emailData = EmailNrGuardianVerifier.EmailData({
                domainName: emailProof.domainName,
                timestamp: emailProof.timestamp,
                accountSalt: accountSalt,
                publicKeyHash: emailProof.publicKeyHash,
                emailNullifier: emailProof.emailNullifier
            });

        proofData = IGuardianVerifier.ProofData({
            proof: emailProof.proof,
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
        EmailNrGuardianVerifier.ProofData
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

        emailProof
            .publicKeyHash = 0x1087f6b1ab2993e76027710b0cd25085b759aaffda8f8aefe04eeaa4df14fccf;
        emailProof
            .emailNullifier = 0x12a412c72a2ec60e1f12860d8ebb3b85fdea87f9ed5cfd805f11f1e619716c29;

        EmailNrGuardianVerifier.EmailData
            memory emailData = EmailNrGuardianVerifier.EmailData({
                domainName: emailProof.domainName,
                timestamp: emailProof.timestamp,
                accountSalt: accountSalt,
                publicKeyHash: emailProof.publicKeyHash,
                emailNullifier: emailProof.emailNullifier
            });

        proofData = IGuardianVerifier.ProofData({
            proof: emailProof.proof,
            data: abi.encode(emailData)
        });
    }
}
