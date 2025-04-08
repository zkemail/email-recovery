// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ModuleKitHelpers} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {EmailRecoveryFactory} from "src/factories/EmailRecoveryFactory.sol";
import {EmailRecoveryModule} from "src/modules/EmailRecoveryModule.sol";

import {BaseTest} from "../Base.t.sol";

import {EmailProof} from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";

import {MockJwtVerifier} from "src/test/MockJwtVerifier.sol";
import {JwtGuardianVerifier} from "src/JwtGuardianVerifier.sol";
import {IGuardianVerifier} from "src/interfaces/IGuardianVerifier.sol";

import {UserOverrideableDKIMRegistry} from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

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

/**
 * Base setup for Jwt Guardian verifier
 */
abstract contract OwnableValidatorRecovery_AbstractedRecoveryModule_Base is
    BaseTest
{
    UserOverrideableDKIMRegistry public dkimRegistry;
    MockJwtVerifier public verifier;

    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    EmailRecoveryFactory public emailRecoveryFactory;
    EmailRecoveryModule public emailRecoveryModule;

    address public emailRecoveryModuleAddress;

    bytes public recoveryData1;
    bytes public recoveryData2;
    bytes public recoveryData3;
    bytes32 public recoveryDataHash1;
    bytes32 public recoveryDataHash2;
    bytes32 public recoveryDataHash3;

    address public jwtGuardianVerifierImplementation;
    bytes public jwtGuardianVerifierInitData;

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

        string
            memory jwtDomainName = "12345|https://example.com|client-id-12345";

        dkimRegistry.setDKIMPublicKeyHash(
            jwtDomainName,
            publicKeyHash,
            zkEmailDeployer,
            new bytes(0)
        );

        verifier = new MockJwtVerifier();

        vm.stopPrank();

        // Setup for the email guardian verifier
        bytes memory initData = abi.encode(
            address(dkimRegistry),
            address(verifier)
        );
        jwtGuardianVerifierInitData = initData;

        // Deploy the email guardian verifier
        jwtGuardianVerifierImplementation = address(new JwtGuardianVerifier());

        guardians1 = new address[](3);
        guardians1[0] = computeGuardianVerifierAuthAddress(
            jwtGuardianVerifierImplementation,
            instance1.account,
            accountSalt1,
            jwtGuardianVerifierInitData
        );
        guardians1[1] = computeGuardianVerifierAuthAddress(
            jwtGuardianVerifierImplementation,
            instance1.account,
            accountSalt2,
            jwtGuardianVerifierInitData
        );
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
    }

    // Helper functions
    function setRecoveryData() public override {
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        recoveryCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        recoveryData = abi.encode(validatorAddress, recoveryCalldata);
        recoveryDataHash = keccak256(recoveryData);
    }

    function generateMockJwtProof(
        string memory command,
        bytes32 nullifier,
        bytes32 accountSalt
    ) public view returns (EmailProof memory) {
        EmailProof memory emailProof;
        emailProof.domainName = "12345|https://example.com|client-id-12345";

        emailProof
            .publicKeyHash = 0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;
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
        JwtGuardianVerifier.ProofData
            memory proofData = getAcceptanceJwtProofData(
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

    function handleRecovery(
        address account,
        address guardian,
        bytes32 _recoveryDataHash,
        address emailRecoveryModule,
        bytes32 accountSalt
    ) public {
        JwtGuardianVerifier.ProofData
            memory proofData = getRecoveryJwtProofData(
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
}
