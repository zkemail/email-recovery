// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployUniversalEmailRecoveryModuleScript } from "../DeployUniversalEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { console } from "forge-std/console.sol";

/// @title DeployUniversalEmailRecoveryModule_Test
/// @notice Contains tests for deploying the Universal Email Recovery Module
contract DeployUniversalEmailRecoveryModule_Test is BaseDeployTest {
    address expectedAddress;

    function setUp() public override {
        super.setUp();

        // Initialize deployer and deployerNonce
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        expectedAddress = computeExpectedAddress(deployer, deployerNonce);
    }

    /// @notice Tests the standard deployment run
    function test_run() public {
        setUp();

        // Deploy the contract
        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    /// @notice Tests the deployment run without a verifier
    function test_run_no_verifier() public {
        setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    /// @notice Tests the deployment run without a DKIM registry
    function test_run_no_dkim_registry() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }
}

/// @title DeployUniversalEmailRecoveryModule_TestFail
/// @notice Contains failing tests for deploying the Universal Email Recovery Module
contract DeployUniversalEmailRecoveryModule_TestFail is BaseDeployTest {
    address expectedAddress;

    function setUp() public override {
        super.setUp();

        // Initialize deployer and deployerNonce
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        expectedAddress = computeExpectedAddress(deployer, deployerNonce);
    }

    /// @notice Tests the deployment run failure without DKIM registry and signer
    function testFail_run_no_dkim_registry_no_signer() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }
}
