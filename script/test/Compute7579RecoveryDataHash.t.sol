// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Compute7579RecoveryDataHash } from "../Compute7579RecoveryDataHash.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract Compute7579RecoveryDataHashTest is BaseDeployTest {
    address expectedAddress;

    function setUp() public override {
        super.setUp();

        // Initialize deployer and deployerNonce
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);
 
        expectedAddress = super.computeExpectedAddress(deployer, deployerNonce);
    }

    function testRun() public {
        // Deploy the contract
        setUp();
        Compute7579RecoveryDataHash target = new Compute7579RecoveryDataHash();

        // Assert the deployed address matches the expected address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

}
