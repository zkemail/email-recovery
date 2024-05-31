// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";

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

import { Solarray } from "solarray/Solarray.sol";
import { MockRegistry } from "../external/MockRegistry.sol";
import { SafeZkEmailRecovery } from "src/SafeZkEmailRecovery.sol";
import { IEmailAccountRecovery } from "src/interfaces/IEmailAccountRecovery.sol";
import { IntegrationBase } from "../IntegrationBase.t.sol";

abstract contract SafeIntegrationBase is IntegrationBase {
    SafeZkEmailRecovery zkEmailRecovery;

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

        zkEmailRecovery = new SafeZkEmailRecovery(
            address(verifier), address(ecdsaOwnedDkimRegistry), address(emailAuthImpl)
        );

        safe = deploySafe();
        accountAddress = address(safe);

        // Compute guardian addresses
        guardian1 = zkEmailRecovery.computeEmailAuthAddress(accountSalt1);
        guardian2 = zkEmailRecovery.computeEmailAuthAddress(accountSalt2);
        guardian3 = zkEmailRecovery.computeEmailAuthAddress(accountSalt3);

        guardians = new address[](3);
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        guardians[2] = guardian3;
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
            owners: Solarray.addresses(owner),
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

    function acceptGuardian(bytes32 accountSalt) public {
        // Uncomment if getting "invalid subject" errors. Sometimes the subject needs updating after
        // certain changes
        // console2.log("accountAddress: ", accountAddress);

        string memory subject =
            "Accept guardian request for 0xE760ccaE42b4EA7a93A4CfA75BC649aaE1033095";

        address router = zkEmailRecovery.getRouterForAccount(accountAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 1"));
        uint256 templateIdx = 0;
        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForAcceptance = new bytes[](1);
        subjectParamsForAcceptance[0] = abi.encode(accountAddress);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: zkEmailRecovery.computeAcceptanceTemplateId(templateIdx),
            subjectParams: subjectParamsForAcceptance,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        IEmailAccountRecovery(router).handleAcceptance(emailAuthMsg, templateIdx);
    }

    function handleRecovery(
        address oldOwner,
        address newOwner,
        address recoveryModule,
        bytes32 accountSalt
    )
        public
    {
        // Uncomment if getting "invalid subject" errors. Sometimes the subject needs updating after
        // certain changes
        // console2.log("accountAddress: ", accountAddress);
        // console2.log("oldOwner:       ", oldOwner);
        // console2.log("newOwner:       ", newOwner);
        // console2.log("recoveryModule: ", recoveryModule);

        string memory subject =
            "Recover account 0xE760ccaE42b4EA7a93A4CfA75BC649aaE1033095 from old owner 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x6d2Fa6974Ef18eB6da842D3c7ab3150326feaEEC";
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(subject, nullifier, accountSalt);

        bytes[] memory subjectParamsForRecovery = new bytes[](4);
        subjectParamsForRecovery[0] = abi.encode(accountAddress);
        subjectParamsForRecovery[1] = abi.encode(oldOwner);
        subjectParamsForRecovery[2] = abi.encode(newOwner);
        subjectParamsForRecovery[3] = abi.encode(recoveryModule);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: zkEmailRecovery.computeRecoveryTemplateId(templateIdx),
            subjectParams: subjectParamsForRecovery,
            skipedSubjectPrefix: 0,
            proof: emailProof
        });
        IEmailAccountRecovery(router).handleRecovery(emailAuthMsg, templateIdx);
    }
}
