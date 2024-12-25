// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeRecovery_Script } from "../DeploySafeRecovery.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract DeploySafeRecovery_Test is BaseDeployTest {
    /**
     * @notice Tests the standard run scenario.
     */
    function test_run() public {
        BaseDeployTest.setUp();
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();
        assertEq(target.initialOwner(), vm.addr(vm.envUint("PRIVATE_KEY")));
        assertEq(target.salt(), vm.envUint("CREATE2_SALT"));
        assertNotEq(target.verifier(), address(0));
    }

    /**
     * @notice Tests the run function without a verifier set.
     */
    function test_run_no_verifier() public {
        BaseDeployTest.setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();
        assertNotEq(target.verifier(), address(0));
        assertNotEq(target.verifier().code.length, 0);
    }

    /**
     * @notice Tests the run function without a DKIM registry.
     */
    function test_run_no_dkim_registry() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        DeploySafeRecovery_Script target = new DeploySafeRecovery_Script();
        target.run();
        assertNotEq(address(target.dkim()), address(0));
        assertNotEq(address(target.dkim()).code.length, 0);// it is a contract
    }
}
