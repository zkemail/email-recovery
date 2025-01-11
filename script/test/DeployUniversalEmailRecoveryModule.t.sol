// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployUniversalEmailRecoveryModuleScript } from "../DeployUniversalEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { console } from "forge-std/console.sol";

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

        // Assert state
        assertState(target);
    }

    /// @notice Tests the deployment run without a verifier
    function test_run_no_verifier() public {
        setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    /// @notice Tests the deployment run without a DKIM registry
    function test_run_no_dkim_registry() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    /// @notice Tests the deployment run without a DKIM signer
    function test_run_no_signer() public {
        setUp();
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    /// @notice Tests the deployment run failure without DKIM registry and signer
    function testFail_run_no_dkim_registry_no_signer() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    /// @notice Helper to assert state after deployment
    function assertState(DeployUniversalEmailRecoveryModuleScript target) internal view {

        // Verify the deployed address
        require(address(target) == expectedAddress, "Deployed address mismatch");
        require(target.verifier() != address(0), "Verifier not deployed correctly");
        require(address(target.dkim()) != address(0), "DKIM Registry not deployed correctly");
        require(target.emailAuthImpl() != address(0), "Email Auth not deployed correctly");
        require(target.minimumDelay() >= 0, "Minimum delay not set correctly");
        require(target.killSwitchAuthorizer() != address(0), "Kill Switch Authorizer not set correctly");
    }
}
