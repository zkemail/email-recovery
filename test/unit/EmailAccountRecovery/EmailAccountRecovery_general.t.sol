// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { EmailAccountRecoveryBase } from "./EmailAccountRecoveryBase.t.sol";

contract EmailAccountRecoveryTest_general is EmailAccountRecoveryBase {
    function test_Verifier() public view {
        assertEq(recoveryController.verifier(), address(verifier));
    }

    function test_DKIM() public view {
        assertEq(recoveryController.dkim(), address(dkimRegistry));
    }

    function test_EmailAuthImplementation() public view {
        assertEq(recoveryController.emailAuthImplementation(), address(emailAuthImpl));
    }
}
