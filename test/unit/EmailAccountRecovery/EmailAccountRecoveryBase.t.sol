// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Verifier, EmailProof } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { EmailAccountRecovery } from "src/EmailAccountRecovery.sol";
import { SimpleWallet } from "src/test/SimpleWallet.sol";
import { RecoveryController } from "src/test/RecoveryController.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract EmailAccountRecoveryBase is UnitBase {
    RecoveryController recoveryController;
    SimpleWallet simpleWallet;

    address guardian;
    address receiver = vm.addr(3);
    address newSigner = vm.addr(4);
    address someRelayer = vm.addr(5);

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(zkEmailDeployer);
        address signer = zkEmailDeployer;

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

        // Create SimpleWallet
        SimpleWallet simpleWalletImpl = new SimpleWallet();
        address recoveryControllerAddress = address(recoveryController);

        ERC1967Proxy simpleWalletProxy = new ERC1967Proxy(
            address(simpleWalletImpl),
            abi.encodeCall(simpleWalletImpl.initialize, (signer, recoveryControllerAddress))
        );
        simpleWallet = SimpleWallet(payable(address(simpleWalletProxy)));
        vm.deal(address(simpleWallet), 1 ether);

        // Set guardian address
        guardian = EmailAccountRecovery(address(recoveryController)).computeEmailAuthAddress(
            address(simpleWallet), accountSalt1
        );

        vm.stopPrank();
    }

    function buildEmailAuthMsg() public returns (EmailAuthMsg memory emailAuthMsg) {
        uint256 templateId = uint256(keccak256(abi.encodePacked("TEST", templateIdx)));

        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(1 ether);
        commandParams[1] = abi.encode("0x0000000000000000000000000000000000000020");

        string memory domainName = "gmail.com";
        uint256 timestamp = 1_694_989_812;
        string memory maskedCommand = "Send 1 ETH to 0x0000000000000000000000000000000000000020";
        bytes32 emailNullifier = 0x00a83fce3d4b1c9ef0f600644c1ecc6c8115b57b1596e0e3295e2c5105fbfd8a;
        bool isCodeExist = true;
        bytes memory mockProof = abi.encodePacked(bytes1(0x01));

        EmailProof memory emailProof = EmailProof({
            domainName: domainName,
            publicKeyHash: publicKeyHash,
            timestamp: timestamp,
            maskedCommand: maskedCommand,
            emailNullifier: emailNullifier,
            accountSalt: accountSalt1,
            isCodeExist: isCodeExist,
            proof: mockProof
        });

        emailAuthMsg = EmailAuthMsg({
            templateId: templateId,
            commandParams: commandParams,
            skippedCommandPrefix: 0,
            proof: emailProof
        });

        vm.mockCall(
            address(verifier),
            abi.encodeCall(Verifier.verifyEmailProof, (emailProof)),
            abi.encode(true)
        );
    }
}
