// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeNativeRecovery_Script } from "../DeploySafeNativeRecovery.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract DeploySafeNativeRecovery_Test is BaseDeployTest {
    /**
     * @notice Tests the basic deployment and execution of the DeploySafeNativeRecovery script.
     */
    function test_run() public {
        // Set up the base test environment
        BaseDeployTest.setUp();

        // Instantiate the script and run it
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }

    /**
     * @notice Tests the deployment and execution of the DeploySafeNativeRecovery script
     *         without a verifier configured.
     */
    function test_run_no_verifier() public {
        // Set up the base test environment
        BaseDeployTest.setUp();

        // Disable the VERIFIER environment variable
        vm.setEnv("ZK_VERIFIER", vm.toString(address(0)));

        // Instantiate the script and run it
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }

    /**
     * @notice Tests the deployment and execution of the DeploySafeNativeRecovery script
     *         without a DKIM registry configured.
     */
    function test_run_no_dkim_registry() public {
        // Set up the base test environment
        BaseDeployTest.setUp();

        // Disable the DKIM_REGISTRY environment variable
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        // Instantiate the script and run it
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }

    /**
     * @notice Tests the deployment and execution of the DeploySafeNativeRecovery script
     *         without a SIGNER configured.
     */
    function test_run_no_signer() public {
        // Set up the base test environment
        BaseDeployTest.setUp();

        // Disable the SIGNER environment variable
        vm.setEnv("SIGNER", vm.toString(address(0)));

        // Instantiate the script and run it
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }
}

contract DeploySafeNativeRecovery_TestFail is BaseDeployTest {
    /**
     * @notice Tests that the DeploySafeNativeRecovery script fails to run
     *         when both DKIM registry and signer are not configured.
     */
    function testFail_run_no_dkim_registry_no_signer() public {
        // Set up the base test environment
        BaseDeployTest.setUp();

        // Disable the DKIM_REGISTRY and SIGNER environment variables
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("SIGNER", vm.toString(address(0)));

        // Instantiate the script and attempt to run it, expecting failure
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }
}
