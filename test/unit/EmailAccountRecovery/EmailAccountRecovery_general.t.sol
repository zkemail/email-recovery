// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { StructHelper } from "../helpers/StructHelper.sol";

contract EmailAccountRecoveryTest_general is Test, StructHelper {
    function test_Verifier() public view {
        assertEq(recoveryController.verifier(), address(verifier));
    }

    function test_DKIM() public view {
        assertEq(recoveryController.dkim(), address(dkim));
    }

    function test_EmailAuthImplementation() public view {
        assertEq(recoveryController.emailAuthImplementation(), address(emailAuth));
    }
}
