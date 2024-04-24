// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {RhinestoneModuleKit, ModuleKitHelpers, ModuleKitUserOp, AccountInstance, UserOpData} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/external/ERC7579.sol";
import {ECDSA} from "solady/src/utils/ECDSA.sol";

import {ZkEmailRecovery} from "src/ZkEmailRecovery.sol";
import {OwnableValidator} from "src/test/OwnableValidator.sol";

import {EmailAuth, EmailAuthMsg, EmailProof} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import {ECDSAOwnedDKIMRegistry} from "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import {MockGroth16Verifier} from "../src/test/MockGroth16Verifier.sol";

contract ZkEmailRecoveryTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    ZkEmailRecovery internal executor;
    OwnableValidator internal validator;

    address public owner;

    // ZK Email contracts and variables
    address zkEmailDeployer = vm.addr(1);
    ECDSAOwnedDKIMRegistry ecdsaOwnedDkimRegistry;
    MockGroth16Verifier verifier;
    bytes32 accountSalt1;
    bytes32 accountSalt2;

    address guardian1;
    address guardian2;

    string selector = "12345";
    string domainName = "gmail.com";
    bytes32 publicKeyHash =
        0x0ea9c777dc7110e5a9e89b13f0cfc540e3845ba120b2b6dc24024d61488d4788;

    function setUp() public {
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
        accountSalt1 = keccak256(abi.encode("account salt 1"));
        accountSalt2 = keccak256(abi.encode("account salt 2"));

        EmailAuth emailAuthImpl = new EmailAuth();
        vm.stopPrank();

        address[] memory owners = new address[](1);
        owner = vm.createWallet("Alice").addr;
        owners[0] = owner;

        // Create the executor
        executor = new ZkEmailRecovery(
            address(verifier),
            address(ecdsaOwnedDkimRegistry),
            address(emailAuthImpl)
        );
        vm.label(address(executor), "ZkEmailRecovery");
        validator = new OwnableValidator();

        // Create the account and install the executor
        instance = makeAccountInstance("ZkEmailRecovery");
        vm.deal(address(instance.account), 10 ether);

        guardian1 = executor.computeEmailAuthAddress(accountSalt1);
        guardian2 = executor.computeEmailAuthAddress(accountSalt2);

        address[] memory guardians;
        guardians[0] = guardian1;
        guardians[1] = guardian2;
        uint256 recoveryDelay = 1 seconds;
        uint256 threshold = 2;

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: address(executor),
            data: abi.encode(guardians, recoveryDelay, threshold)
        });

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, owner)
        });
    }

    function testRecover() public {
        // Functions we need to call without going through a validator and instead would be called via a relayer
        //
        // 1.
        // IZkEmailRecovery(routerAddress).handleAcceptance(
        //     emailAuthMsg,
        //     templateIdx
        // );
        //
        // 2.
        // IZkEmailRecovery(routerAddress).handleRecovery(
        //     emailAuthMsg,
        //     templateIdx
        // );
        //
        // 3.
        // IZkEmailRecovery(routerAddress).completeRecovery();
        //
        // Assert owner has changed
        //
        // assertTrue(isOwner);
        // assertFalse(oldOwnerIsOwner);
    }
}
