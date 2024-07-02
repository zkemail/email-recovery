// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import {
    SafeProxy,
    SafeProxyFactory
} from "@safe-global/safe-contracts/contracts/proxies/SafeProxyFactory.sol";
import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { IERC7484 } from "safe7579/interfaces/IERC7484.sol";
import { Safe7579 } from "safe7579/Safe7579.sol";
import { ModuleInit } from "safe7579/DataTypes.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { ExecutionLib } from "erc7579/lib/ExecutionLib.sol";
import { ModeLib } from "erc7579/lib/ModeLib.sol";
import { ISafe7579 } from "safe7579/ISafe7579.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { etchEntrypoint, IEntryPoint } from "modulekit/test/predeploy/EntryPoint.sol";
import { MockExecutor, MockTarget } from "modulekit/Mocks.sol";
import { MockValidator } from "module-bases/mocks/MockValidator.sol";
import { EmailAuthMsg, EmailProof } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SubjectUtils } from "ether-email-auth/packages/contracts/src/libraries/SubjectUtils.sol";
import { Solarray } from "solarray/Solarray.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { EmailRecoveryManagerHarness } from "./EmailRecoveryManagerHarness.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { SafeRecoverySubjectHandlerHarness } from "./SafeRecoverySubjectHandlerHarness.sol";
import { EmailRecoveryFactory } from "src/EmailRecoveryFactory.sol";
import { MockRegistry } from "src/test/MockRegistry.sol";
import { IntegrationBase } from "../integration/IntegrationBase.t.sol";

abstract contract SafeUnitBase is IntegrationBase {
    using Strings for uint256;

    EmailRecoveryFactory emailRecoveryFactory;
    SafeRecoverySubjectHandlerHarness safeRecoverySubjectHandler;
    EmailRecoveryManager emailRecoveryManager;
    address emailRecoveryManagerAddress;
    address recoveryModuleAddress;

    bytes4 functionSelector;
    bytes recoveryCalldata;
    bytes32 calldataHash;

    Safe7579 safe7579;
    Safe singleton;
    Safe safe;
    SafeProxyFactory safeProxyFactory;
    Safe7579Launchpad launchpad;

    MockValidator defaultValidator;
    MockExecutor defaultExecutor;
    MockTarget target;

    IEntryPoint entrypoint;
    IERC7484 registry;

    function setUp() public virtual override {
        super.setUp();

        // Deploy handler, manager and module
        safeRecoverySubjectHandler = new SafeRecoverySubjectHandlerHarness();
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));

        emailRecoveryManager = new EmailRecoveryManagerHarness(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl),
            address(safeRecoverySubjectHandler)
        );
        emailRecoveryManagerAddress = address(emailRecoveryManager);

        UniversalEmailRecoveryModule emailRecoveryModule =
            new UniversalEmailRecoveryModule(emailRecoveryManagerAddress);
        recoveryModuleAddress = address(emailRecoveryModule);
        emailRecoveryManager.initialize(recoveryModuleAddress);

        safe = deploySafe();
        accountAddress1 = address(safe);

        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));
        address previousOwnerInLinkedList = address(1);
        // address previousOwnerInLinkedList =
        //     safeRecoverySubjectHandler.previousOwnerInLinkedList(accountAddress, owner);
        recoveryCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", previousOwnerInLinkedList, owner1, newOwner1
        );
        calldataHash = keccak256(recoveryCalldata);

        // Compute guardian addresses
        guardians1 = new address[](3);
        guardians1[0] =
            emailRecoveryManager.computeEmailAuthAddress(instance1.account, accountSalt1);
        guardians1[1] =
            emailRecoveryManager.computeEmailAuthAddress(instance1.account, accountSalt2);
        guardians1[2] =
            emailRecoveryManager.computeEmailAuthAddress(instance1.account, accountSalt3);
    }

    /**
     * Taken from safe7579/test/Launchpad.t.sol
     */
    function deploySafe() internal returns (Safe) {
        entrypoint = etchEntrypoint();
        singleton = new Safe();
        safeProxyFactory = new SafeProxyFactory();
        registry = new MockRegistry();
        safe7579 = new Safe7579();
        launchpad = new Safe7579Launchpad(address(entrypoint), registry);

        // Set up Modules
        defaultValidator = new MockValidator();
        defaultExecutor = new MockExecutor();
        target = new MockTarget();

        bytes32 salt;

        ModuleInit[] memory validators = new ModuleInit[](1);
        validators[0] = ModuleInit({ module: address(defaultValidator), initData: bytes("") });
        ModuleInit[] memory executors = new ModuleInit[](1);
        executors[0] = ModuleInit({ module: address(defaultExecutor), initData: bytes("") });
        ModuleInit[] memory fallbacks = new ModuleInit[](0);
        ModuleInit[] memory hooks = new ModuleInit[](0);

        Safe7579Launchpad.InitData memory initData = Safe7579Launchpad.InitData({
            singleton: address(singleton),
            owners: Solarray.addresses(owner1),
            threshold: 1,
            setupTo: address(launchpad),
            setupData: abi.encodeCall(
                Safe7579Launchpad.initSafe7579,
                (
                    address(safe7579),
                    executors,
                    fallbacks,
                    hooks,
                    Solarray.addresses(makeAddr("attester1"), makeAddr("attester2")),
                    2
                )
            ),
            safe7579: ISafe7579(safe7579),
            validators: validators,
            callData: abi.encodeCall(
                IERC7579Account.execute,
                (
                    ModeLib.encodeSimpleSingle(),
                    ExecutionLib.encodeSingle({
                        target: address(target),
                        value: 0,
                        callData: abi.encodeCall(MockTarget.set, (1337))
                    })
                )
            )
        });
        bytes32 initHash = launchpad.hash(initData);

        bytes memory factoryInitializer =
            abi.encodeCall(Safe7579Launchpad.preValidationSetup, (initHash, address(0), ""));

        PackedUserOperation memory userOp =
            getDefaultUserOp(address(safe), address(defaultValidator));

        {
            userOp.callData = abi.encodeCall(Safe7579Launchpad.setupSafe, (initData));
            userOp.initCode = _initCode(factoryInitializer, salt);
        }

        address predict = launchpad.predictSafeAddress({
            singleton: address(launchpad),
            safeProxyFactory: address(safeProxyFactory),
            creationCode: type(SafeProxy).creationCode,
            salt: salt,
            factoryInitializer: factoryInitializer
        });
        userOp.sender = predict;
        assertEq(userOp.sender, predict);
        userOp.signature = abi.encodePacked(
            uint48(0), uint48(type(uint48).max), hex"4141414141414141414141414141414141"
        );

        entrypoint.getUserOpHash(userOp);
        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOp;
        deal(address(userOp.sender), 1 ether);

        entrypoint.handleOps(userOps, payable(address(0x69)));

        return Safe(payable(predict));
    }

    function _initCode(
        bytes memory initializer,
        bytes32 salt
    )
        internal
        view
        returns (bytes memory initCode)
    {
        initCode = abi.encodePacked(
            address(safeProxyFactory),
            abi.encodeCall(
                SafeProxyFactory.createProxyWithNonce,
                (address(launchpad), initializer, uint256(salt))
            )
        );
    }

    function getDefaultUserOp(
        address account,
        address validator
    )
        internal
        view
        returns (PackedUserOperation memory userOp)
    {
        userOp = PackedUserOperation({
            sender: account,
            nonce: safe7579.getNonce(account, validator),
            initCode: "",
            callData: "",
            accountGasLimits: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            preVerificationGas: 2e6,
            gasFees: bytes32(abi.encodePacked(uint128(2e6), uint128(2e6))),
            paymasterAndData: bytes(""),
            signature: abi.encodePacked(hex"41414141")
        });
    }

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

    function acceptGuardian(address account, bytes32 accountSalt) public {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory subject = string.concat("Accept guardian request for ", accountString);

        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));
        uint256 templateIdx = 0;
        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(account);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryManager.computeAcceptanceTemplateId(templateIdx),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        emailRecoveryManager.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function handleRecovery(address account, bytes32 accountSalt) public {
        string memory accountString = SubjectUtils.addressToChecksumHexString(account);
        string memory calldataHashString = uint256(calldataHash).toHexString(32);
        string memory recoveryModuleString =
            SubjectUtils.addressToChecksumHexString(recoveryModuleAddress);

        string memory subjectPart1 = string.concat("Recover account ", accountString);
        string memory subjectPart2 = string.concat(" via recovery module ", recoveryModuleString);
        string memory subjectPart3 = string.concat(" using recovery hash ", calldataHashString);
        string memory subject = string.concat(subjectPart1, subjectPart2, subjectPart3);
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](3);
        subjectParamsForRecovery[0] = abi.encode(account);
        subjectParamsForRecovery[1] = abi.encode(recoveryModuleAddress);
        subjectParamsForRecovery[2] = abi.encode(calldataHashString);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryManager.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        emailRecoveryManager.handleRecovery(emailAuthMsg, templateIdx);
    }
}
