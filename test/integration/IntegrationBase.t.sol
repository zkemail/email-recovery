// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import "forge-std/console2.sol";

import {RhinestoneModuleKit, AccountInstance} from "modulekit/ModuleKit.sol";
import {ECDSAOwnedDKIMRegistry} from "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import {EmailAuth} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {ECDSA} from "solady/utils/ECDSA.sol";

import {MockGroth16Verifier} from "src/test/MockGroth16Verifier.sol";

abstract contract IntegrationBase is RhinestoneModuleKit, Test {
    // ZK Email contracts and variables
    address zkEmailDeployer = vm.addr(1);
    ECDSAOwnedDKIMRegistry ecdsaOwnedDkimRegistry;
    MockGroth16Verifier verifier;
    EmailAuth emailAuthImpl;

    // account and owners
    AccountInstance instance;
    address accountAddress;
    address owner;
    address newOwner;

    // recovery config
    address[] guardians;
    address guardian1;
    address guardian2;
    address guardian3;
    uint256[] guardianWeights;
    uint256 delay;
    uint256 expiry;
    uint256 threshold;
    uint templateIdx;

    // Account salts
    bytes32 accountSalt1;
    bytes32 accountSalt2;
    bytes32 accountSalt3;

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;

    function setUp() public virtual {
        init();

        // Create ZK Email contracts
        vm.startPrank(zkEmailDeployer);
        ecdsaOwnedDkimRegistry = new ECDSAOwnedDKIMRegistry(zkEmailDeployer);
        string memory signedMsg = ecdsaOwnedDkimRegistry.computeSignedMsg(
            ecdsaOwnedDkimRegistry.SET_PREFIX(),
            selector,
            domainName,
            publicKeyHash
        );
        bytes32 digest = ECDSA.toEthSignedMessageHash(bytes(signedMsg));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, digest);
        bytes memory signature = abi.encodePacked(r, s, v);
        ecdsaOwnedDkimRegistry.setDKIMPublicKeyHash(
            selector,
            domainName,
            publicKeyHash,
            signature
        );

        verifier = new MockGroth16Verifier();
        emailAuthImpl = new EmailAuth();
        vm.stopPrank();

        // create owners
        owner = vm.createWallet("owner").addr;
        newOwner = vm.createWallet("newOwner").addr;
        address[] memory owners = new address[](1);
        owners[0] = owner;

        // Deploy and fund the account
        instance = makeAccountInstance("account");
        accountAddress = instance.account;
        vm.deal(address(instance.account), 10 ether);

        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));
        accountSalt3 = keccak256(abi.encode("account salt 3"));

        // Set recovery config variables
        guardianWeights = new uint256[](3);
        guardianWeights[0] = 1;
        guardianWeights[1] = 1;
        guardianWeights[2] = 1;
        delay = 1 seconds;
        expiry = 2 weeks;
        threshold = 2;
        templateIdx = 0;
    }
}
