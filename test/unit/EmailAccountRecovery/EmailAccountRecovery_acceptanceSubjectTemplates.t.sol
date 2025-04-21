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

contract EmailAccountRecoveryTest_acceptanceCommandTemplates is EmailAccountRecoveryBase {
    constructor() { }

    function setUp() public override {
        super.setUp();
    }

    function testAcceptanceCommandTemplates() public {
        string[][] memory res = recoveryController.acceptanceCommandTemplates();
        assertEq(res[0][0], "Accept");
        assertEq(res[0][1], "guardian");
        assertEq(res[0][2], "request");
        assertEq(res[0][3], "for");
        assertEq(res[0][4], "{ethAddr}");
    }
}
