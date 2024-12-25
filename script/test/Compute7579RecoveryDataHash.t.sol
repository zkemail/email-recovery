// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Compute7579RecoveryDataHash } from "../Compute7579RecoveryDataHash.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract Compute7579RecoveryDataHashTest is BaseDeployTest {
    function setUp() public override {
        super.setUp();
    }

    function testRun() public {
        Compute7579RecoveryDataHash target = new Compute7579RecoveryDataHash();
        target.run();
        assertNotEq(target.recoveryDataHash() , bytes32(0));
        assertNotEq(target.newOwner() , address(0));
    }
}
