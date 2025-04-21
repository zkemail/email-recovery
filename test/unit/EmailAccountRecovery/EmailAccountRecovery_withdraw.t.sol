// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";
import { OwnableUpgradeable } from
    "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract EmailAccountRecoveryTest_withdraw is EmailAccountRecoveryBase {
    function setUp() public override {
        super.setUp();
    }

    function testWithdraw() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(zkEmailDeployer.balance, 0 ether);

        vm.startPrank(zkEmailDeployer);
        simpleWallet.withdraw(1 ether);
        vm.stopPrank();

        assertEq(address(simpleWallet).balance, 0 ether);
        assertEq(zkEmailDeployer.balance, 1 ether);
    }

    function testExpectRevertWithdrawOnlyOwner() public {
        assertEq(address(simpleWallet).balance, 1 ether);
        assertEq(zkEmailDeployer.balance, 0 ether);

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
        assertEq(zkEmailDeployer.balance, 0 ether);

        vm.startPrank(zkEmailDeployer);
        vm.expectRevert(bytes("insufficient balance"));
        simpleWallet.withdraw(10 ether);
        vm.stopPrank();
    }
}
