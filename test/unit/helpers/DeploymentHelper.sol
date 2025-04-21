// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Verifier, EmailProof } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { SimpleWallet } from "./SimpleWallet.sol";
import { RecoveryController, EmailAccountRecovery } from "./RecoveryController.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploymentHelper is Test {
    using ECDSA for *;

    EmailAuth emailAuth;
    Verifier verifier;
    ECDSAOwnedDKIMRegistry dkim;
    UserOverrideableDKIMRegistry overrideableDkimImpl;
    RecoveryController recoveryController;
    SimpleWallet simpleWalletImpl;
    SimpleWallet simpleWallet;

    address deployer = vm.addr(1);
    address receiver = vm.addr(2);
    address guardian;
    address newSigner = vm.addr(4);
    address someRelayer = vm.addr(5);

    bytes32 accountSalt;
    uint256 templateId;
    string[] commandTemplate;
    string[] newCommandTemplate;
    bytes mockProof = abi.encodePacked(bytes1(0x01));

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash = 0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;
    bytes32 emailNullifier = 0x00a83fce3d4b1c9ef0f600644c1ecc6c8115b57b1596e0e3295e2c5105fbfd8a;
    uint256 setTimestampDelay = 3 days;

    bytes32 public proxyBytecodeHash = vm.envOr("PROXY_BYTECODE_HASH", bytes32(0));

    function setUp() public virtual {
        vm.startPrank(deployer);
        address signer = deployer;

        // Create DKIM registry
        {
            ECDSAOwnedDKIMRegistry ecdsaDkimImpl = new ECDSAOwnedDKIMRegistry();
            ERC1967Proxy ecdsaDkimProxy = new ERC1967Proxy(
                address(ecdsaDkimImpl), abi.encodeCall(ecdsaDkimImpl.initialize, (deployer, signer))
            );
            dkim = ECDSAOwnedDKIMRegistry(address(ecdsaDkimProxy));
        }
        string memory signedMsg =
            dkim.computeSignedMsg(dkim.SET_PREFIX(), domainName, publicKeyHash);
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(bytes(signedMsg));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        dkim.setDKIMPublicKeyHash(selector, domainName, publicKeyHash, signature);

        // Create userOverrideable dkim registry implementation
        overrideableDkimImpl = new UserOverrideableDKIMRegistry();
        // {
        //     UserOverrideableDKIMRegistry overrideableDkimImpl = new
        // UserOverrideableDKIMRegistry();
        //     ERC1967Proxy overrideableDkimProxy = new ERC1967Proxy(
        //         address(overrideableDkimImpl),
        //         abi.encodeCall(
        //             overrideableDkimImpl.initialize,
        //             (deployer, signer, setTimestampDelay)
        //         )
        //     );
        //     overrideableDkim = UserOverrideableDKIMRegistry(
        //         address(overrideableDkimProxy)
        //     );
        // }
        // overrideableDkim.setDKIMPublicKeyHash(
        //     domainName,
        //     publicKeyHash,
        //     deployer,
        //     new bytes(0)
        // );

        // Create Verifier
        {
            Verifier verifierImpl = new Verifier();
            console.log("Verifier implementation deployed at: %s", address(verifierImpl));
            Groth16Verifier groth16Verifier = new Groth16Verifier();
            ERC1967Proxy verifierProxy = new ERC1967Proxy(
                address(verifierImpl),
                abi.encodeCall(verifierImpl.initialize, (msg.sender, address(groth16Verifier)))
            );
            verifier = Verifier(address(verifierProxy));
        }
        accountSalt = 0x2c3abbf3d1171bfefee99c13bf9c47f1e8447576afd89096652a34f27b297971;

        // Create EmailAuth implementation
        EmailAuth emailAuthImpl = new EmailAuth();
        emailAuth = emailAuthImpl;

        uint256 templateIdx = 0;
        templateId = uint256(keccak256(abi.encodePacked("TEST", templateIdx)));
        commandTemplate = ["Send", "{decimals}", "ETH", "to", "{ethAddr}"];
        newCommandTemplate = ["Send", "{decimals}", "USDC", "to", "{ethAddr}"];

        // Create RecoveryController as EmailAccountRecovery implementation
        RecoveryController recoveryControllerImpl = new RecoveryController();
        ERC1967Proxy recoveryControllerProxy = new ERC1967Proxy(
            address(recoveryControllerImpl),
            abi.encodeCall(
                recoveryControllerImpl.initialize,
                (signer, address(verifier), address(dkim), address(emailAuthImpl))
            )
        );
        recoveryController = RecoveryController(payable(address(recoveryControllerProxy)));

        // Create SimpleWallet
        simpleWalletImpl = new SimpleWallet();
        address recoveryControllerAddress = address(recoveryController);

        ERC1967Proxy simpleWalletProxy = new ERC1967Proxy(
            address(simpleWalletImpl),
            abi.encodeCall(simpleWalletImpl.initialize, (signer, recoveryControllerAddress))
        );
        simpleWallet = SimpleWallet(payable(address(simpleWalletProxy)));
        vm.deal(address(simpleWallet), 1 ether);

        // Set guardian address
        guardian = EmailAccountRecovery(address(recoveryController)).computeEmailAuthAddress(
            address(simpleWallet), accountSalt
        );

        vm.stopPrank();
    }

    function resetEnviromentVariables() public {
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(0)));
        vm.setEnv("INITIAL_OWNER", vm.toString(uint256(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        vm.setEnv("DKIM", vm.toString(address(0)));
        vm.setEnv("DKIM_DELAY", vm.toString(uint256(0)));
        vm.setEnv("ECDSA_DKIM", vm.toString(address(0)));
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(address(0)));
        vm.setEnv("RECOVERY_CONTROLLER", vm.toString(address(0)));
        vm.setEnv("SIMPLE_WALLET", vm.toString(address(0)));
    }
}
