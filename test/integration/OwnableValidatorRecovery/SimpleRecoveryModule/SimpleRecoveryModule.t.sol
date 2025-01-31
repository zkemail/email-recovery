// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { BaseTest, CommandHandlerType } from "../../../Base.t.sol";
import { SimpleRecoveryModule } from "src/modules/SimpleRecoveryModule.sol";
import { SimpleGuardianManager } from "src/SimpleGuardianManager.sol";
import { SignatureVerifier } from "src/verifiers/SignatureVerifier.sol";
import { console } from "forge-std/console.sol";
import { EmailProof } from "@zk-email/ether-email-auth-contracts/src/interfaces/IVerifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";

contract SimpleRecoveryModule_Test is BaseTest {
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    EmailRecoveryFactory public emailRecoveryFactory;
    address public commandHandlerAddress;
    EmailRecoveryModule public emailRecoveryModule;

    address public emailRecoveryModuleAddress;

    address public simpleRecoveryModuleAddress;

    address public simpleGuardianManagerAddress;

    address public signatureVerifierAddress;

    address public groth16verifier;

    bytes public recoveryData1;

    bytes32 public recoveryDataHash1;

    address[] guardians;

    uint256 public recoveryId;

    function setUp() public virtual override {
        super.setUp();

        signatureVerifierAddress = address(new SignatureVerifier());
        groth16verifier = address(new MockGroth16Verifier());

        simpleRecoveryModuleAddress = address(
            new SimpleRecoveryModule(validatorAddress, signatureVerifierAddress, groth16verifier)
        );

        simpleGuardianManagerAddress = address(new SimpleGuardianManager());

        recoveryId = block.timestamp;

        bytes memory changeOwnerCalldata1 = abi.encodeWithSelector(functionSelector, newOwner1);

        recoveryData1 = abi.encode(validatorAddress, changeOwnerCalldata1);

        recoveryDataHash1 = keccak256(recoveryData1);

        guardians.push(owner2);
        guardians.push(owner3);

        bytes memory setGuardiansCalldata = abi.encodeWithSignature(
            "setGuardians(address,address[],uint256)", instance1.account, guardians, 1
        );

        bytes memory recoveryModuleInstallData1 =
            abi.encode(setGuardiansCalldata, simpleGuardianManagerAddress, owner2);

        // Install modules for account 1
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1)
        });

        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: simpleRecoveryModuleAddress,
            data: recoveryModuleInstallData1
        });
    }

    function test_RecoverByEmail() public {
        uint256 currentTime = block.timestamp;

        string memory accountString = CommandUtils.addressToChecksumHexString(instance1.account);
        string memory oldOwnerString = CommandUtils.addressToChecksumHexString(owner1);
        string memory newOwnerString = CommandUtils.addressToChecksumHexString(newOwner1);

        string memory command =
            "Recover account 0xF4F7b3D8e43a41833774CD6d962D10282f806017 from old owner 0xCe9A87013DB006Dde79E7382bf48D45bF891e90D to new owner 0x63aaF092604406C03E5B36ca1bEc1CDDF4a5Fa9d";
        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt1 = keccak256(abi.encode("account salt 3"));

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt3);

        MockGroth16Verifier groth16Verifier = MockGroth16Verifier(groth16verifier);

        bytes memory emailProofInBytes = abi.encode(
            emailProof.domainName,
            emailProof.publicKeyHash,
            emailProof.timestamp,
            emailProof.maskedCommand,
            emailProof.emailNullifier,
            emailProof.accountSalt,
            emailProof.isCodeExist,
            emailProof.proof
        );

        bytes memory markedProof = abi.encode(bytes1(0x00), emailProofInBytes);

        (bytes1 firstByte, bytes memory proof) = abi.decode(markedProof, (bytes1, bytes));

        assert(firstByte == bytes1(0x00));

        (
            string memory domainName,
            bytes32 publicKeyHash,
            uint256 timestamp,
            string memory maskedCommand,
            bytes32 emailNullifier,
            bytes32 accountSalt,
            bool isCodeExist,
            bytes memory proof2
        ) = abi.decode(proof, (string, bytes32, uint256, string, bytes32, bytes32, bool, bytes));

        EmailProof memory emailProof2 = EmailProof(
            domainName,
            publicKeyHash,
            timestamp,
            maskedCommand,
            emailNullifier,
            accountSalt,
            isCodeExist,
            proof2
        );

        bool result = groth16Verifier.verifyEmailProof(emailProof2); 
        assert(result);
    }

    function test_VerifySignature_Success() public {
        SignatureVerifier signatureVerifier = new SignatureVerifier();

        bytes32 messageHash = keccak256(abi.encodePacked("Test message"));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(vm.createWallet("owner2"), messageHash);
        bytes memory signature = abi.encodePacked(r, s, v); // Ensure packed encoding

        address acc = signatureVerifier.recoverSigner(messageHash, signature);
        assert(acc == owner2);

        bool result = signatureVerifier.verifySignature(owner2, messageHash, signature);
        assert(result);

        bytes memory combinedProof = abi.encode(owner2, messageHash, signature);
        bytes memory markedProof = abi.encode(bytes1(0x00), combinedProof);

        (bytes1 firstByte, bytes memory proof) = abi.decode(markedProof, (bytes1, bytes));
        assert(firstByte == bytes1(0x00));

        (address signer, bytes32 messageHash2, bytes memory signature2) =
            abi.decode(proof, (address, bytes32, bytes));

        assert(signer == owner2);
        assert(messageHash2 == messageHash);
        assertEq(signature2, signature);
    }

    function test_RecoverAccount_With_EOA_ZKEmail() public {
        SimpleRecoveryModule simpleRecoveryModule =
            SimpleRecoveryModule(simpleRecoveryModuleAddress);
        SimpleGuardianManager guardianManager = SimpleGuardianManager(simpleGuardianManagerAddress);

        simpleRecoveryModule.initiateRecovery(instance1.account);

        // EOA Proof
        bytes32 messageHash = keccak256(abi.encodePacked("Test message"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(vm.createWallet("owner2"), messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        bytes memory proof = abi.encode(owner2, messageHash, signature);
        bytes memory markedProof = abi.encode(bytes1(0x01), proof);
        vm.prank(owner2);
        guardianManager.submitProof(instance1.account, recoveryId, markedProof);

        //zkEmail Proof
        string memory command =
            "Recover account 0xF4F7b3D8e43a41833774CD6d962D10282f806017 from old owner 0xCe9A87013DB006Dde79E7382bf48D45bF891e90D to new owner 0x63aaF092604406C03E5B36ca1bEc1CDDF4a5Fa9d";
        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt1 = keccak256(abi.encode("account salt 3"));
        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt3);
        bytes memory emailProofInBytes = abi.encode(
            emailProof.domainName,
            emailProof.publicKeyHash,
            emailProof.timestamp,
            emailProof.maskedCommand,
            emailProof.emailNullifier,
            emailProof.accountSalt,
            emailProof.isCodeExist,
            emailProof.proof
        );

        bytes memory markedProofEmail = abi.encode(bytes1(0x00), emailProofInBytes);
        vm.prank(owner3);
        guardianManager.submitProof(instance1.account, recoveryId, markedProofEmail);

        simpleRecoveryModule.recover(instance1.account, recoveryData, recoveryId);

        address updatedOwners = validator.owners(instance1.account);

        assertEq(updatedOwners, newOwner1);

        vm.prank(owner2);
        guardianManager.setRecoveryCompleted(instance1.account, 1);
    }

    // Helper functions

    function computeEmailAuthAddress(
        address account,
        bytes32 accountSalt
    )
        public
        view
        override
        returns (address)
    {
        return emailRecoveryModule.computeEmailAuthAddress(account, accountSalt);
    }

    function deployModule(bytes memory handlerBytecode) public override {
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));

        bytes32 commandHandlerSalt = bytes32(uint256(0));
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        (emailRecoveryModuleAddress, commandHandlerAddress) = emailRecoveryFactory
            .deployEmailRecoveryModule(
            commandHandlerSalt,
            recoveryModuleSalt,
            handlerBytecode,
            minimumDelay,
            killSwitchAuthorizer,
            address(dkimRegistry),
            validatorAddress,
            functionSelector
        );
        emailRecoveryModule = EmailRecoveryModule(emailRecoveryModuleAddress);

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress1
            );
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress2
            );
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress3
            );
        }
    }

    function setRecoveryData() public override {
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        recoveryCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        recoveryData = abi.encode(validatorAddress, recoveryCalldata);
        recoveryDataHash = keccak256(recoveryData);
    }
}
