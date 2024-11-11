// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployEmailRecoveryModuleScript } from
    "script/7579/EmailRecoveryModule/DeployEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "../../BaseDeployTest.sol";

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
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
    }

    /**
     * @dev Tests the deployment process when the VERIFIER environment variable is not set.
     */
    function test_run_no_verifier() public {
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
    }

    /**
     * @dev Tests the deployment process when the DKIM_REGISTRY environment variable is not set.
     */
    function test_run_no_dkim_registry() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
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
     * variables are
     * not set.
     */
    function testFail_run_no_dkim_registry_no_signer() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
    }
}
