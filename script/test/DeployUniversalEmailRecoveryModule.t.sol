// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployUniversalEmailRecoveryModuleScript } from
    "../DeployUniversalEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailRecoveryModule } from "src/EmailRecoveryModule.sol";

/// @title DeployUniversalEmailRecoveryModule_Test
/// @notice Contains tests for deploying the Universal Email Recovery Module
contract DeployUniversalEmailRecoveryModule_Test is BaseDeployTest {
    /// @notice Tests the standard deployment run
    function test_run() public {
        uint256 snapshot = vm.snapshot();
        BaseDeployTest.setUp();
        
        DeployUniversalEmailRecoveryModuleScript target = 
            new DeployUniversalEmailRecoveryModuleScript();
        
        // Record initial state
        address initialVerifier = vm.envAddress("VERIFIER");
        address initialDKIMRegistry = vm.envAddress("DKIM_REGISTRY");
        
        // Run deployment
        target.run();
        
        // Verify factory deployment and configuration
        address factory = vm.envAddress("RECOVERY_FACTORY");
        assertTrue(factory.code.length > 0, "Factory not deployed");
        EmailRecoveryUniversalFactory factoryContract = EmailRecoveryUniversalFactory(factory);
        
        // Verify factory configuration
        assertEq(factoryContract.verifier(), initialVerifier, "Factory verifier mismatch");
        assertEq(factoryContract.emailAuthImpl(), vm.envAddress("EMAIL_AUTH_IMPL"), "Factory emailAuth mismatch");
        
        // Verify module deployment
        (address module, address handler) = factoryContract.getLastDeployment();
        assertTrue(module != address(0), "Module not deployed");
        assertTrue(handler != address(0), "Handler not deployed");
        
        // Verify module configuration
        EmailRecoveryModule moduleContract = EmailRecoveryModule(module);
        assertEq(moduleContract.verifier(), initialVerifier, "Module verifier mismatch");
        assertEq(moduleContract.dkimRegistry(), initialDKIMRegistry, "Module DKIM registry mismatch");
        assertEq(moduleContract.killSwitchAuthorizer(), vm.envAddress("KILL_SWITCH_AUTHORIZER"), "Module kill switch mismatch");
        
        vm.revertTo(snapshot);
    }

    /// @notice Tests the deployment run without a verifier
    function test_run_no_verifier() public {
        uint256 snapshot = vm.snapshot();
        BaseDeployTest.setUp();
        
        // Setup test condition
        address initialVerifier = vm.envAddress("VERIFIER");
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        
        DeployUniversalEmailRecoveryModuleScript target = 
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();
        
        // Verify new verifier was deployed
        address newVerifier = vm.envAddress("VERIFIER");
        assertTrue(newVerifier != address(0), "No verifier deployed");
        assertTrue(newVerifier != initialVerifier, "Verifier not updated");
        assertTrue(newVerifier.code.length > 0, "Verifier has no code");
        
        vm.revertTo(snapshot);
    }

    /// @notice Tests the deployment run without a DKIM registry
    function test_run_no_dkim_registry() public {
        uint256 snapshot = vm.snapshot();
        BaseDeployTest.setUp();
        
        // Setup test condition
        address initialRegistry = vm.envAddress("DKIM_REGISTRY");
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        
        DeployUniversalEmailRecoveryModuleScript target = 
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();
        
        // Verify new registry was deployed
        address newRegistry = vm.envAddress("DKIM_REGISTRY");
        assertTrue(newRegistry != address(0), "No registry deployed");
        assertTrue(newRegistry != initialRegistry, "Registry not updated");
        assertTrue(newRegistry.code.length > 0, "Registry has no code");
        
        vm.revertTo(snapshot);
    }
}

/// @title DeployUniversalEmailRecoveryModule_TestFail
/// @notice Contains failing tests for deploying the Universal Email Recovery Module
contract DeployUniversalEmailRecoveryModule_TestFail is BaseDeployTest {
    /// @notice Tests the deployment run failure without DKIM registry and signer
    function testFail_run_no_dkim_registry_no_signer() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        
        DeployUniversalEmailRecoveryModuleScript target = 
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();
    }
}
