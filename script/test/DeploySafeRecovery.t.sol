// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeRecovery_Script } from "../DeploySafeRecovery.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { console } from "forge-std/console.sol";

contract DeploySafeRecovery_Test is BaseDeployTest {
    address expectedAddress;

    function setUp() public override {
        super.setUp();

        // Initialize deployer and deployerNonce
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        expectedAddress = computeExpectedAddress(deployer, deployerNonce);
    }

    function test_run() public {
        setUp();

        // Deploy the contract
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();

        // Assert state
        assertState(target);
    }

    function test_run_no_verifier() public {
        setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));

        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();

        // Assert state
        assertState(target);
    }

    function test_run_no_dkim_registry() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();

        // Assert state
        assertState(target);
    }

    function test_run_no_signer() public {
        setUp();
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();

        // Assert state
        assertState(target);
    }

    function testFail_run_no_dkim_registry_no_signer() public {
        setUp();

        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();

        target.run();

        // Assert state
        assertState(target);
    }

    // Helper to assert state after deployment
    function assertState(DeploySafeRecovery_Script target) internal view {
        
        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
        // Add require statements to validate state
        require(target.verifier() != address(0), "Verifier not deployed correctly");
        require(address(target.dkim()) != address(0), "DKIM Registry not deployed correctly");
        require(target.emailAuthImpl() != address(0), "Email Auth not deployed correctly");
        require(target.minimumDelay() >= 0, "Minimum delay not set correctly");
    }
}
