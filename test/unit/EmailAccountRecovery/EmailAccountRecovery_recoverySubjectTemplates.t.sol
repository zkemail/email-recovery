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

contract EmailAccountRecoveryTest_recoveryCommandTemplates is EmailAccountRecoveryBase {
    constructor() { }

    function setUp() public override {
        super.setUp();
    }

    function testRecoveryCommandTemplates() public {
        string[][] memory res = recoveryController.recoveryCommandTemplates();
        assertEq(res[0][0], "Set");
        assertEq(res[0][1], "the");
        assertEq(res[0][2], "new");
        assertEq(res[0][3], "signer");
        assertEq(res[0][4], "of");
        assertEq(res[0][5], "{ethAddr}");
        assertEq(res[0][6], "to");
        assertEq(res[0][7], "{ethAddr}");
    }
}
