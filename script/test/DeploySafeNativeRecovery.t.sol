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
    
    function test_run() public {
        setUp();

        // Deploy the contract
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_verifier() public {
        setUp();
        vm.setEnv("ZK_VERIFIER", vm.toString(address(0)));

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_dkim_registry() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_signer() public {
        setUp();
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }
}
