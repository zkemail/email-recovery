// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployEmailRecoveryModuleScript } from "../DeployEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { console } from "forge-std/console.sol";

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

        // Assert state
        assertState(target);
    }

    function test_run_no_verifier() public {
        setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));

        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    function test_run_no_dkim_registry() public {
        setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    function test_run_no_email_auth_impl() public {
        setUp();
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(address(0)));

        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    function test_run_no_validator() public {
        setUp();
        vm.setEnv("VALIDATOR", vm.toString(address(0)));

        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert state
        assertState(target);
    }

    function assertState(DeployEmailRecoveryModuleScript target) internal view {
        // Assert that the contract is deployed at the correct address
        require(address(target) == expectedAddress, "Deployed address mismatch");

        // Add assertions to check the state of the contract after deployment
        require(target.verifier() != address(0), "Verifier not deployed correctly");
        require(address(target.dkim()) != address(0), "DKIM Registry not deployed correctly");
        require(target.emailAuthImpl() != address(0), "Email Auth not deployed correctly");
        require(target.minimumDelay() >= 0, "Minimum delay not set correctly");
        require(target.killSwitchAuthorizer() != address(0), "Kill Switch Authorizer not set correctly");
    }
}

contract DeployEmailRecoveryModule_TestFail is BaseDeployTest {
    function testFail_run_no_dkim_registry_no_signer() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();

        // Expect the run to fail due to missing DKIM_REGISTRY and DKIM_SIGNER
        vm.expectRevert("DKIM_SIGNER cannot be zero address");
        target.run();
    }
}
