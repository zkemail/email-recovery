// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EoaAuth, EoaAuthMsg} from "../../src/EoaAuth.sol";
import {Verifier, EoaProof} from "../../src/utils/Verifier.sol";
import {Groth16Verifier} from "../../src/circuits/Groth16Verifier.sol";
import {ECDSAOwnedDKIMRegistry} from "../../src/utils/ECDSAOwnedDKIMRegistry.sol";
import {UserOverrideableDKIMRegistry} from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploymentHelper is Test {
    
    using ECDSA for *;

    EoaAuth eoaAuth;
    Verifier verifier;
    ECDSAOwnedDKIMRegistry dkim;
    UserOverrideableDKIMRegistry overrideableDkimImpl;

    /// @dev - Stored-value below (139..734) would be coming from the public.json, which was generated via the ZK circuit.
    uint256[34] public pubSignals = [uint256(1390849295786071768276380950238675083608645509734)];

    address deployer = vm.addr(1);
    address receiver = vm.addr(2);
    address guardian;
    address newSigner = vm.addr(4);
    address someRelayer = vm.addr(5);

    bytes32 accountSalt;
    uint templateId;
    string[] commandTemplate;
    string[] newCommandTemplate;
    bytes mockProof = abi.encodePacked(bytes1(0x01));

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;
    bytes32 eoaNullifier =
        0x00a83fce3d4b1c9ef0f600644c1ecc6c8115b57b1596e0e3295e2c5105fbfd8a;
    uint256 setTimestampDelay = 3 days;

    bytes32 public proxyBytecodeHash =
        vm.envOr("PROXY_BYTECODE_HASH", bytes32(0));

    function setUp() public virtual {
        vm.startPrank(deployer);
        address signer = deployer;

        // Create DKIM registry
        {
            ECDSAOwnedDKIMRegistry ecdsaDkimImpl = new ECDSAOwnedDKIMRegistry();
            ERC1967Proxy ecdsaDkimProxy = new ERC1967Proxy(
                address(ecdsaDkimImpl),
                abi.encodeCall(ecdsaDkimImpl.initialize, (deployer, signer))
            );
            dkim = ECDSAOwnedDKIMRegistry(address(ecdsaDkimProxy));
        }
        string memory signedMsg = dkim.computeSignedMsg(
            dkim.SET_PREFIX(),
            domainName,
            publicKeyHash
        );
        bytes32 digest = MessageHashUtils.toEthSignedMessageHash(
            bytes(signedMsg)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        dkim.setDKIMPublicKeyHash(
            selector,
            domainName,
            publicKeyHash,
            signature
        );

        // Create userOverrideable dkim registry implementation
        overrideableDkimImpl = new UserOverrideableDKIMRegistry();

        // Create Verifier
        {
            Verifier verifierImpl = new Verifier();
            console.log(
                "Verifier implementation deployed at: %s",
                address(verifierImpl)
            );
            Groth16Verifier groth16Verifier = new Groth16Verifier();
            ERC1967Proxy verifierProxy = new ERC1967Proxy(
                address(verifierImpl),
                abi.encodeCall(
                    verifierImpl.initialize,
                    (msg.sender, address(groth16Verifier))
                )
            );
            verifier = Verifier(address(verifierProxy));
        }
        accountSalt = 0x2c3abbf3d1171bfefee99c13bf9c47f1e8447576afd89096652a34f27b297971;

        // Create EoaAuth implementation
        EoaAuth eoaAuthImpl = new EoaAuth();
        eoaAuth = eoaAuthImpl;

        uint templateIdx = 0;
        templateId = uint256(keccak256(abi.encodePacked("TEST", templateIdx)));
        commandTemplate = ["Send", "{decimals}", "ETH", "to", "{ethAddr}"];
        newCommandTemplate = ["Send", "{decimals}", "USDC", "to", "{ethAddr}"];

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
        vm.setEnv("RECOVERY_CONTROLLER_ZKSYNC", vm.toString(address(0)));
        vm.setEnv("ZKSYNC_CREATE2_FACTORY", vm.toString(address(0)));
        vm.setEnv("SIMPLE_WALLET", vm.toString(address(0)));
    }
}
