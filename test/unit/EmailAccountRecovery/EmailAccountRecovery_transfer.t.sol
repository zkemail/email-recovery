// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { RecoveryController } from "src/test/RecoveryController.sol";
import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";
import { SimpleWallet } from "src/test/SimpleWallet.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EmailAccountRecoveryTest_transfer is EmailAccountRecoveryBase {
    constructor() { }

    function setUp() public override {
        super.setUp();
    }

    function testTransfer() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(receiver.balance, 0 ether);

        vm.startPrank(zkEmailDeployer);
        simpleWallet.transfer(receiver, 1 ether);
        vm.stopPrank();

        assertEq(address(simpleWallet).balance, 0 ether);
        assertEq(receiver.balance, 1 ether);
    }

    function testExpectRevertTransferOnlyOwner() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(receiver.balance, 0 ether);

        vm.startPrank(receiver);
        vm.expectRevert(
            abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, receiver)
        );
        simpleWallet.transfer(receiver, 1 ether);
        vm.stopPrank();
    }

    function testExpectRevertTransferOnlyOwnerInsufficientBalance() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(receiver.balance, 0 ether);

        vm.startPrank(zkEmailDeployer);
        assertEq(receiver.balance, 0 ether);
        vm.expectRevert(bytes("insufficient balance"));
        simpleWallet.transfer(receiver, 2 ether);
        vm.stopPrank();
    }
}
