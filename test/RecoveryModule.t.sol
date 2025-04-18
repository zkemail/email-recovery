// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, AccountInstance} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import {OwnableValidator} from "@rhinestone/core-modules/src/OwnableValidator/OwnableValidator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Verifier} from "@zk-email/email-tx-builder/utils/Verifier.sol";
import {ECDSAOwnedDKIMRegistry} from "@zk-email/email-tx-builder/utils/ECDSAOwnedDKIMRegistry.sol";
import {IVerifier} from "@zk-email/email-tx-builder/interfaces/IVerifier.sol";
import {EmailAuthMsg} from "@zk-email/email-tx-builder/interfaces/IEmailTypes.sol";
import {EmailSigner} from "@zk-email/email-tx-builder/EmailSigner.sol";
import {EmailAuthMsgFixtures} from "@zk-email/email-tx-builder-fixtures/EmailAuthMsgFixtures.sol";
import {Groth16Verifier} from "@zk-email/email-tx-builder-fixtures/Groth16Verifier.sol";

import {RecoveryModule} from "../src/RecoveryModule.sol";
import {ECDSAGuardian} from "../src/ECDSAGuardian.sol";
import {EmailGuardian} from "../src/EmailGuardian.sol";

contract RecoveryModuleTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;

    RecoveryModule public recoveryModule;
    OwnableValidator public validator;

    address public recoveryModuleAddress;
    address public validatorAddress;

    ECDSAGuardian public ecdsaGuardian;
    address public ecdsaGuardianAddress;
    address public ecdsaGuardianSigner;
    uint256 public ecdsaGuardianSignerPk;

    EmailGuardian public emailGuardian;
    address public emailGuardianAddress;

    address testSigner;
    uint256 testSignerPrivateKey;

    bytes32 public accountSalt;
    ECDSAOwnedDKIMRegistry public dkimRegistry;
    IVerifier public verifier;
    uint256 public templateId;

    AccountInstance public account;
    address public accountAddress;

    address[] public owners;
    uint256[] public ownerPks;
    uint256 public ownersThreshold;

    address[] public guardians;
    uint256 public recoveryThreshold;
    uint256 public delay;
    uint256 public expiry;

    function setUp() public {
        recoveryModule = new RecoveryModule();
        validator = new OwnableValidator();

        recoveryModuleAddress = address(recoveryModule);
        validatorAddress = address(validator);

        (ecdsaGuardianSigner, ecdsaGuardianSignerPk) = makeAddrAndKey(
            "ecdsaGuardianSigner"
        );
        ECDSAGuardian ecdsaGuardianImpl = new ECDSAGuardian();
        ERC1967Proxy ecdsaGuardianProxy = new ERC1967Proxy(
            address(ecdsaGuardianImpl),
            abi.encodeCall(ecdsaGuardianImpl.initialize, (ecdsaGuardianSigner))
        );
        ecdsaGuardian = ECDSAGuardian(address(ecdsaGuardianProxy));
        ecdsaGuardianAddress = address(ecdsaGuardianProxy);

        // Setup test signer for DKIM registry
        testSignerPrivateKey = uint256(
            keccak256(abi.encodePacked("test signer key"))
        );
        testSigner = vm.addr(testSignerPrivateKey);

        // Setup verifier with a compatible Groth16Verifier
        verifier = Verifier(
            address(
                new ERC1967Proxy(
                    address(new Verifier()),
                    abi.encodeWithSelector(
                        Verifier.initialize.selector,
                        testSigner,
                        address(new Groth16Verifier()) // needs to match proofs
                    )
                )
            )
        );

        // Setup DKIM registry with test configuration
        dkimRegistry = ECDSAOwnedDKIMRegistry(
            address(
                new ERC1967Proxy(
                    address(new ECDSAOwnedDKIMRegistry()),
                    abi.encodeWithSelector(
                        ECDSAOwnedDKIMRegistry.initialize.selector,
                        address(this),
                        testSigner
                    )
                )
            )
        );
        EmailAuthMsg memory emailAuthMsg = EmailAuthMsgFixtures.getCase1();
        _setupDKIMRegistry(emailAuthMsg);

        accountSalt = emailAuthMsg.proof.accountSalt;
        dkimRegistry = dkimRegistry;
        verifier = verifier;
        templateId = emailAuthMsg.templateId;

        EmailGuardian emailGuardianImpl = new EmailGuardian();
        ERC1967Proxy emailGuardianProxy = new ERC1967Proxy(
            address(emailGuardianImpl),
            abi.encodeCall(
                emailGuardianImpl.initialize,
                (accountSalt, dkimRegistry, verifier, templateId)
            )
        );

        emailGuardian = EmailGuardian(address(emailGuardianProxy));
        emailGuardianAddress = address(emailGuardianProxy);

        account = makeAccountInstance("account");
        accountAddress = account.account;
        vm.deal(address(accountAddress), 10 ether);

        owners = new address[](2);
        owners[0] = vm.createWallet("owner1").addr;
        owners[1] = vm.createWallet("owner2").addr;
        ownersThreshold = 2;

        recoveryThreshold = 1;
        delay = 1 days;
        expiry = 2 weeks;

        guardians = new address[](2);
        guardians[0] = ecdsaGuardianAddress;
        guardians[1] = emailGuardianAddress;

        (owners, ) = generateAndsortOwners();
        bytes memory data = abi.encode(ownersThreshold, owners);

        account.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: data
        });

        account.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                validatorAddress,
                guardians,
                recoveryThreshold,
                delay,
                expiry
            )
        });
    }

    function generateAndsortOwners()
        internal
        returns (address[] memory, uint256[] memory)
    {
        address[] memory _owners = new address[](2);
        uint256[] memory _ownerPks = new uint256[](2);

        (address owner1, uint256 owner1Pk) = makeAddrAndKey("owner1");
        (address owner2, uint256 owner2Pk) = makeAddrAndKey("owner2");

        _owners[0] = owner1;
        _ownerPks[0] = owner1Pk;

        uint256 counter = 0;
        while (uint160(owner1) > uint160(owner2)) {
            counter++;
            (owner2, owner2Pk) = makeAddrAndKey(vm.toString(counter));
        }
        _owners[1] = owner2;
        _ownerPks[1] = owner2Pk;

        return (_owners, _ownerPks);
    }

    /// @notice Configures DKIM dkimRegistry for a fixture
    /// @param emailAuthMsg The fixture containing DKIM data to register
    function _setupDKIMRegistry(EmailAuthMsg memory emailAuthMsg) internal {
        string memory signedMsg = dkimRegistry.computeSignedMsg(
            dkimRegistry.SET_PREFIX(),
            emailAuthMsg.proof.domainName,
            emailAuthMsg.proof.publicKeyHash
        );

        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(
            bytes(signedMsg)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(testSignerPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s, v);

        dkimRegistry.setDKIMPublicKeyHash(
            "DEFAULT", // Registry identifier (not validated in current implementation)
            emailAuthMsg.proof.domainName,
            emailAuthMsg.proof.publicKeyHash,
            signature
        );
    }

    function test_RecoveryModule_ECDSAGuardianRecoversAValidator() public {
        bytes4 functionSelector = bytes4(
            keccak256(bytes("setThreshold(uint256)"))
        );
        bytes memory recoveryCalldata = abi.encodeWithSelector(
            functionSelector,
            1
        );

        bytes32 hash = keccak256(recoveryCalldata);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ecdsaGuardianSignerPk, hash);
        bytes memory ecdsaSignature = abi.encodePacked(r, s, v);

        recoveryModule.approveRecovery(
            accountAddress,
            validatorAddress,
            ecdsaGuardianAddress,
            ecdsaSignature,
            hash
        );

        vm.warp(block.timestamp + delay);

        uint256 thresholdBefore = validator.threshold(accountAddress);
        recoveryModule.executeRecovery(
            accountAddress,
            validatorAddress,
            recoveryCalldata
        );
        uint256 thresholdAfter = validator.threshold(accountAddress);

        assertEq(thresholdBefore, 2);
        assertEq(thresholdAfter, 1);
    }

    function test_RecoveryModule_EmailGuardianRecoversAValidator() public {
        bytes4 functionSelector = bytes4(
            keccak256(bytes("setThreshold(uint256)"))
        );
        bytes memory recoveryCalldata = abi.encodeWithSelector(
            functionSelector,
            1
        );

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsgFixtures.getCase1();
        bytes32 hash = bytes32(emailAuthMsg.commandParams[0]);
        bytes memory emailSignature = abi.encode(emailAuthMsg);

        recoveryModule.approveRecovery(
            accountAddress,
            validatorAddress,
            emailGuardianAddress,
            emailSignature,
            hash
        );
        (, , uint256 approvals, ) = recoveryModule.getRecoveryRequest(
            accountAddress,
            validatorAddress
        );
        assertEq(approvals, 1);

        // FIXME: (merge-ok) Since the EmailAuth fixtures are hardcoded, we cannot
        // enforce that the hash is a hash over the recoveryCalldata. If this function
        // is called now, we get a `InvalidRecoveryDataHash` error

        // vm.warp(block.timestamp + delay);

        // uint256 thresholdBefore = validator.threshold(accountAddress);
        // recoveryModule.executeRecovery(
        //     accountAddress,
        //     validatorAddress,
        //     recoveryCalldata
        // );
        // uint256 thresholdAfter = validator.threshold(accountAddress);

        // assertEq(thresholdBefore, 2);
        // assertEq(thresholdAfter, 1);
    }
}
