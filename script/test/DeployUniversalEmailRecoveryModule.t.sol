// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployUniversalEmailRecoveryModuleScript } from
    "../DeployUniversalEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

/// @title DeployUniversalEmailRecoveryModule_Test
/// @notice Contains tests for deploying the Universal Email Recovery Module
contract DeployUniversalEmailRecoveryModule_Test is BaseDeployTest {
    /// @notice Tests the standard deployment run
    function test_run() public {
        BaseDeployTest.setUp();
        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();
        assertNotEq(target.initialOwner(), address(0));
        assertNotEq(target.verifier() , address(0));
    }

    /// @notice Tests the deployment run without a verifier
    function test_run_no_verifier() public {
        BaseDeployTest.setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();
        assertNotEq(target.verifier(), address(0));
        assertNotEq(target.verifier().code.length, 0);
    }

    /// @notice Tests the deployment run without a DKIM registry
    function test_run_no_dkim_registry() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();
        assertNotEq(address(target.dkim()), address(0));
        assertNotEq(address(target.dkim()).code.length, 0);
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
            vm.expectRevert();
        target.run();
    }
}
