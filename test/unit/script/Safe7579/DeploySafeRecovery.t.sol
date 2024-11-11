// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeRecovery_Script } from "script/Safe7579/DeploySafeRecovery.s.sol";
import { BaseDeployTest } from "../BaseDeployTest.sol";

contract DeploySafeRecovery_Test is BaseDeployTest {
    /**
     * @notice Tests the standard run scenario.
     */
    function test_run() public {
        BaseDeployTest.setUp();
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();
    }

    /**
     * @notice Tests the run function without a verifier set.
     */
    function test_run_no_verifier() public {
        BaseDeployTest.setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();
    }

    /**
     * @notice Tests the run function without a DKIM registry.
     */
    function test_run_no_dkim_registry() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();
    }
}
