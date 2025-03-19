// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { RecoveryController } from "../helpers/RecoveryController.sol";
import { StructHelper } from "../helpers/StructHelper.sol";
import { SimpleWallet } from "../helpers/SimpleWallet.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EmailAccountRecoveryTest_withdraw is StructHelper {
    constructor() { }

    function setUp() public override {
        super.setUp();
    }

    function testWithdraw() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(deployer.balance, 0 ether);

        vm.startPrank(deployer);
        simpleWallet.withdraw(1 ether);
        vm.stopPrank();

        assertEq(address(simpleWallet).balance, 0 ether);
        assertEq(deployer.balance, 1 ether);
    }

    function testExpectRevertWithdrawOnlyOwner() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(deployer.balance, 0 ether);

        vm.startPrank(receiver);
        vm.expectRevert(
            abi.encodeWithSelector(
                OwnableUpgradeable.OwnableUnauthorizedAccount.selector, address(receiver)
            )
        );
        simpleWallet.withdraw(1 ether);
        vm.stopPrank();
    }

    function testExpectRevertWithdrawInsufficientBalance() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(deployer.balance, 0 ether);

        vm.startPrank(deployer);
        vm.expectRevert(bytes("insufficient balance"));
        simpleWallet.withdraw(10 ether);
        vm.stopPrank();
    }
}
