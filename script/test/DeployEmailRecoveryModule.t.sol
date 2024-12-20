// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { DeployEmailRecoveryModuleScript } from "../DeployEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { EmailRecoveryModule } from "../../src/modules/EmailRecoveryModule.sol";
import { EmailRecoveryManager } from "../../src/EmailRecoveryManager.sol";

/**
 * @title DeployEmailRecoveryModule_Test
 * @dev Test contract for deploying the Email Recovery Module
 */
contract DeployEmailRecoveryModule_Test is BaseDeployTest {
    /**
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        super.setUp();
    }

    /**
     * @dev Tests that the standard deployment process executes correctly.
     */
    function test_run() public {
        uint256 snapshot = vm.snapshot();
        
        // Record initial state
        address initialVerifier = vm.envAddress("VERIFIER");
        address initialDKIMRegistry = vm.envAddress("DKIM_REGISTRY");
        
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        // Verify module deployment and configuration
        address module = vm.envAddress("RECOVERY_MODULE");
        assertTrue(module.code.length > 0, "Module not deployed");
        
        EmailRecoveryModule moduleContract = EmailRecoveryModule(module);
        assertEq(moduleContract.verifier(), initialVerifier, "Module verifier mismatch");
        assertEq(moduleContract.dkimAddr(), initialDKIMRegistry, "Module DKIM registry mismatch");
        assertEq(
            moduleContract.owner(),
            vm.envAddress("KILL_SWITCH_AUTHORIZER"),
            "Module kill switch authorizer mismatch"
        );
        
        vm.revertTo(snapshot);
    }

    /**
     * @dev Tests the deployment process when the VERIFIER environment variable is not set.
     */
    function test_run_no_verifier() public {
        uint256 snapshot = vm.snapshot();
        
        // Setup test condition
        address initialVerifier = vm.envAddress("VERIFIER");
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        // Verify new verifier was deployed
        address newVerifier = vm.envAddress("VERIFIER");
        assertTrue(newVerifier != address(0), "No verifier deployed");
        assertTrue(newVerifier != initialVerifier, "Verifier not updated");
        assertTrue(newVerifier.code.length > 0, "Verifier has no code");
        
        // Verify module uses new verifier
        address module = vm.envAddress("RECOVERY_MODULE");
        assertEq(
            EmailRecoveryModule(module).verifier(),
            newVerifier,
            "Module not using new verifier"
        );
        
        vm.revertTo(snapshot);
    }

    /**
     * @dev Tests the deployment process when the DKIM_REGISTRY environment variable is not set.
     */
    function test_run_no_dkim_registry() public {
        uint256 snapshot = vm.snapshot();
        
        // Setup test condition
        address initialRegistry = vm.envAddress("DKIM_REGISTRY");
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        // Verify new registry was deployed
        address newRegistry = vm.envAddress("DKIM_REGISTRY");
        assertTrue(newRegistry != address(0), "No registry deployed");
        assertTrue(newRegistry != initialRegistry, "Registry not updated");
        assertTrue(newRegistry.code.length > 0, "Registry has no code");
        
        // Verify module uses new registry
        address module = vm.envAddress("RECOVERY_MODULE");
        assertEq(
            EmailRecoveryModule(module).dkimAddr(),
            newRegistry,
            "Module not using new registry"
        );
        
        vm.revertTo(snapshot);
    }
}

/**
 * @title DeployEmailRecoveryModule_TestFail
 * @dev Test contract for failure scenarios when deploying the Email Recovery Module
 */
contract DeployEmailRecoveryModule_TestFail is BaseDeployTest {
    /**
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        super.setUp();
    }

    /**
     * @dev Tests that deployment fails when both DKIM_REGISTRY and DKIM_SIGNER environment
     * variables are not set.
     */
    function testFail_run_no_dkim_registry_no_signer() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
    }
}
