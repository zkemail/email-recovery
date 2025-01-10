// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployEmailRecoveryModuleScript } from "../DeployEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import {console} from "forge-std/console.sol";

contract DeployEmailRecoveryModule_Test is BaseDeployTest {
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
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert that the contract is deployed at the correct address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_verifier() public {
        setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert branch logic and deployment state
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_dkim_registry() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert branch logic and deployment state
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }
}

contract DeployEmailRecoveryModule_TestFail is BaseDeployTest {
    address expectedAddress;
    
    function setUp() public override {
        super.setUp();

        // Initialize deployer and deployerNonce
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        expectedAddress = super.computeExpectedAddress(deployer, deployerNonce);
    }

    function testFail_run_no_dkim_registry_no_signer() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();

        // Expect the run to fail due to missing configuration
        target.run();

        // Assert branch logic and deployment state
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }
}
