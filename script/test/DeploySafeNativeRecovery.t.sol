// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeNativeRecovery_Script } from "../DeploySafeNativeRecovery.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { console } from "forge-std/console.sol";

contract DeploySafeNativeRecovery_Test is BaseDeployTest {
    address expectedAddress;

    function setUp() public override {
        super.setUp();

        // Initialize deployer and deployerNonce
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        expectedAddress = super.computeExpectedAddress(deployer, deployerNonce);
    }
    
    // Test the default deployment path
    function test_run() public {
        setUp();

        // Deploy the contract
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Additional assertions for deployed state
        assertState(target);
    }

    // Test missing ZK_VERIFIER branch
    function test_run_no_verifier() public {
        setUp();
        vm.setEnv("ZK_VERIFIER", vm.toString(address(0)));

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Additional assertions for branch state
        assertState(target);
    }

    // Test missing DKIM_REGISTRY branch
    function test_run_no_dkim_registry() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Additional assertions for branch state
        assertState(target);
    }

    // Test missing DKIM_SIGNER branch
    function test_run_no_signer() public {
        setUp();
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Additional assertions for branch state
        assertState(target);
    }

    // Helper to assert the deployed state
    function assertState(DeploySafeNativeRecovery_Script target) internal view {
        
        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");

        // Add specific require/assert statements for expected state
        require(target.verifier() != address(0), "Verifier not deployed correctly");
        require(address(target.dkim()) != address(0), "DKIM Registry not deployed correctly");
        require(target.emailAuthImpl() != address(0), "Email Auth implementation not deployed correctly");
        require(target.commandHandler() != address(0), "Command Handler not deployed correctly");
    }
}
