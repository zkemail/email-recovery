// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console  */

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { SimpleWallet } from "src/test/SimpleWallet.sol";
import { RecoveryController } from "src/test/RecoveryController.sol";
import { console } from "forge-std/console.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract IntegrationTest is Test {
    using Strings for *;
    using console for *;

    EmailAuth public emailAuth;
    Verifier public verifier;
    UserOverrideableDKIMRegistry public dkimRegistry;

    RecoveryController public recoveryController;
    SimpleWallet public simpleWallet;

    address public deployer = vm.addr(1);
    address public receiver = vm.addr(2);
    address public guardian = vm.addr(3);
    address public relayer = deployer;

    bytes32 public accountSalt;
    string public selector = "12345";
    string public domainName = "gmail.com";
    bytes32 public publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;
    uint256 public recoveryTimelock = 5 days;
    uint256 public setTimeDelay = 3 days;

    function setUp() public {
        vm.createSelectFork("https://mainnet.base.org", 22_739_283);
        vm.rollFork(22_739_283);

        vm.startPrank(deployer);
        address signer = deployer;

        // Create DKIM registry
        UserOverrideableDKIMRegistry overrideableDkimImpl = new UserOverrideableDKIMRegistry();
        {
            ERC1967Proxy overrideableDkimProxy = new ERC1967Proxy(
                address(overrideableDkimImpl),
                abi.encodeCall(overrideableDkimImpl.initialize, (msg.sender, signer, setTimeDelay))
            );
            dkimRegistry = UserOverrideableDKIMRegistry(address(overrideableDkimProxy));
        }
        {
            string memory signedMsg =
                dkimRegistry.computeSignedMsg(dkimRegistry.SET_PREFIX(), domainName, publicKeyHash);
            bytes32 digest = MessageHashUtils.toEthSignedMessageHash(bytes(signedMsg));
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
            bytes memory signature = abi.encodePacked(r, s, v);
            dkimRegistry.setDKIMPublicKeyHash(domainName, publicKeyHash, signer, signature);
            vm.warp(block.timestamp + setTimeDelay + 1);
        }

        // Create Verifier
        {
            Verifier verifierImpl = new Verifier();
            Groth16Verifier groth16Verifier = new Groth16Verifier();
            ERC1967Proxy verifierProxy = new ERC1967Proxy(
                address(verifierImpl),
                abi.encodeCall(verifierImpl.initialize, (msg.sender, address(groth16Verifier)))
            );
            verifier = Verifier(address(verifierProxy));
        }

        // Create EmailAuth
        EmailAuth emailAuthImpl = new EmailAuth();
        console.log("emailAuthImpl");
        console.logAddress(address(emailAuthImpl));

        // Create RecoveryController as EmailAccountRecovery implementation
        RecoveryController recoveryControllerImpl = new RecoveryController();
        ERC1967Proxy recoveryControllerProxy = new ERC1967Proxy(
            address(recoveryControllerImpl),
            abi.encodeCall(
                recoveryControllerImpl.initialize,
                (signer, address(verifier), address(dkimRegistry), address(emailAuthImpl))
            )
        );
        recoveryController = RecoveryController(payable(address(recoveryControllerProxy)));

        // Create SimpleWallet as EmailAccountRecovery implementation
        SimpleWallet simpleWalletImpl = new SimpleWallet();
        ERC1967Proxy simpleWalletProxy = new ERC1967Proxy(
            address(simpleWalletImpl),
            abi.encodeCall(simpleWalletImpl.initialize, (signer, address(recoveryController)))
        );
        simpleWallet = SimpleWallet(payable(address(simpleWalletProxy)));
        vm.stopPrank();
        vm.startPrank(address(simpleWallet));
        recoveryController.configureTimelockPeriod(recoveryTimelock);
        vm.stopPrank();
    }

    function testIntegration_Account_Recovery() public {
        // FIXME: make integration test work
        vm.skip(true);
        console.log("testIntegration_Account_Recovery");

        bytes32 accountCode = 0x1162ebff40918afe5305e68396f0283eb675901d0387f97d21928d423aaa0b54;
        uint256 templateIdx = 0;

        vm.startPrank(relayer);
        vm.deal(address(relayer), 1 ether);

        console.log("SimpleWallet is at ", address(simpleWallet));
        assertEq(address(simpleWallet), 0x46080822b1906e932858BB9580A90610b2028e9b);
        address simpleWalletOwner = simpleWallet.owner();

        // Verify the email proof for acceptance
        string[] memory inputGenerationInput = new string[](3);
        inputGenerationInput[0] = string.concat(vm.projectRoot(), "/test/bin/accept.sh");
        inputGenerationInput[1] = string.concat(
            vm.projectRoot(), "/test/emails/", block.chainid.toString(), "/accept.eml"
        );
        inputGenerationInput[2] = uint256(accountCode).toHexString(32);
        vm.ffi(inputGenerationInput);

        string memory publicInputFile = vm.readFile(
            string.concat(vm.projectRoot(), "/test/build_integration/email_auth_public.json")
        );
        string[] memory pubSignals = abi.decode(vm.parseJson(publicInputFile), (string[]));

        EmailProof memory emailProof;
        emailProof.domainName = "gmail.com";
        emailProof.publicKeyHash = bytes32(vm.parseUint(pubSignals[9]));
        emailProof.timestamp = vm.parseUint(pubSignals[11]);
        emailProof.maskedCommand =
            "Accept guardian request for 0x46080822b1906e932858BB9580A90610b2028e9b";
        emailProof.emailNullifier = bytes32(vm.parseUint(pubSignals[10]));
        emailProof.accountSalt = bytes32(vm.parseUint(pubSignals[32]));
        accountSalt = emailProof.accountSalt;
        emailProof.isCodeExist = vm.parseUint(pubSignals[33]) == 1;
        emailProof.proof = proofToBytes(
            string.concat(vm.projectRoot(), "/test/build_integration/email_auth_proof.json")
        );

        console.log("dkim public key hash: ");
        console.logBytes32(bytes32(vm.parseUint(pubSignals[9])));
        console.log("email nullifier: ");
        console.logBytes32(bytes32(vm.parseUint(pubSignals[10])));
        console.log("timestamp: ", vm.parseUint(pubSignals[11]));
        console.log("account salt: ");
        console.logBytes32(bytes32(vm.parseUint(pubSignals[32])));
        console.log("is code exist: ", vm.parseUint(pubSignals[33]));

        // Call Request guardian -> GuardianStatus.REQUESTED
        guardian = recoveryController.computeEmailAuthAddress(address(simpleWallet), accountSalt);
        recoveryController.requestGuardian(guardian);
        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.REQUESTED)
        );

        // Call handleAcceptance -> GuardianStatus.ACCEPTED
        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(address(simpleWallet));
        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: recoveryController.computeAcceptanceTemplateId(templateIdx),
            commandParams: commandParamsForAcceptance,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
        recoveryController.handleAcceptance(emailAuthMsg, templateIdx);
        assertEq(
            uint256(recoveryController.guardians(guardian)),
            uint256(RecoveryController.GuardianStatus.ACCEPTED)
        );

        // Verify the email proof for recovery
        inputGenerationInput = new string[](3);
        inputGenerationInput[0] = string.concat(vm.projectRoot(), "/test/bin/recovery.sh");
        inputGenerationInput[1] = string.concat(
            vm.projectRoot(), "/test/emails/", block.chainid.toString(), "/recovery.eml"
        );
        inputGenerationInput[2] = uint256(accountCode).toHexString(32);
        vm.ffi(inputGenerationInput);

        publicInputFile = vm.readFile(
            string.concat(vm.projectRoot(), "/test/build_integration/email_auth_public.json")
        );
        pubSignals = abi.decode(vm.parseJson(publicInputFile), (string[]));

        // EmailProof memory emailProof;
        emailProof.domainName = "gmail.com";
        emailProof.publicKeyHash = bytes32(vm.parseUint(pubSignals[9]));
        emailProof.timestamp = vm.parseUint(pubSignals[11]);
        emailProof.maskedCommand = string.concat(
            "Set the new signer of 0x46080822b1906e932858BB9580A90610b2028e9b ",
            "to 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720"
        );
        emailProof.emailNullifier = bytes32(vm.parseUint(pubSignals[10]));
        emailProof.accountSalt = bytes32(vm.parseUint(pubSignals[32]));
        assertEq(emailProof.accountSalt, accountSalt);
        emailProof.isCodeExist = vm.parseUint(pubSignals[33]) == 1;
        emailProof.proof = proofToBytes(
            string.concat(vm.projectRoot(), "/test/build_integration/email_auth_proof.json")
        );

        console.log("dkim public key hash: ");
        console.logBytes32(bytes32(vm.parseUint(pubSignals[9])));
        console.log("email nullifier: ");
        console.logBytes32(bytes32(vm.parseUint(pubSignals[10])));
        console.log("timestamp: ", vm.parseUint(pubSignals[11]));
        console.log("account salt: ");
        console.logBytes32(bytes32(vm.parseUint(pubSignals[32])));
        console.log("is code exist: ", vm.parseUint(pubSignals[33]));

        // Call handleRecovery -> isRecovering = true;
        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(address(simpleWallet));
        commandParamsForRecovery[1] =
            abi.encode(address(0xa0Ee7A142d267C1f36714E4a8F75612F20a79720));
        emailAuthMsg = EmailAuthMsg({
            templateId: recoveryController.computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
        recoveryController.handleRecovery(emailAuthMsg, templateIdx);
        assertTrue(recoveryController.isRecovering(address(simpleWallet)));
        assertEq(
            recoveryController.newSignerCandidateOfAccount(address(simpleWallet)),
            0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
        );
        assertGt(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), simpleWalletOwner);

        // Call completeRecovery
        vm.warp(block.timestamp + recoveryTimelock + 1);
        recoveryController.completeRecovery(address(simpleWallet), new bytes(0));
        console.log("simpleWallet owner: ", simpleWallet.owner());
        assertFalse(recoveryController.isRecovering(address(simpleWallet)));
        assertEq(recoveryController.newSignerCandidateOfAccount(address(simpleWallet)), address(0));
        assertEq(recoveryController.currentTimelockOfAccount(address(simpleWallet)), 0);
        assertEq(simpleWallet.owner(), 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720);
        vm.stopPrank();
    }

    function proofToBytes(string memory proofPath) internal view returns (bytes memory) {
        string memory proofFile = vm.readFile(proofPath);
        string[] memory pi_a = abi.decode(vm.parseJson(proofFile, ".pi_a"), (string[]));
        uint256[2] memory pA = [vm.parseUint(pi_a[0]), vm.parseUint(pi_a[1])];
        string[][] memory pi_b = abi.decode(vm.parseJson(proofFile, ".pi_b"), (string[][]));
        uint256[2][2] memory pB = [
            [vm.parseUint(pi_b[0][1]), vm.parseUint(pi_b[0][0])],
            [vm.parseUint(pi_b[1][1]), vm.parseUint(pi_b[1][0])]
        ];
        string[] memory pi_c = abi.decode(vm.parseJson(proofFile, ".pi_c"), (string[]));
        uint256[2] memory pC = [vm.parseUint(pi_c[0]), vm.parseUint(pi_c[1])];
        bytes memory proof = abi.encode(pA, pB, pC);
        return proof;
    }
}
