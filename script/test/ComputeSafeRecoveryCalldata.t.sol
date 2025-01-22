// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { ComputeSafeRecoveryCalldataScript } from "../ComputeSafeRecoveryCalldata.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract ComputeSafeRecoveryCalldataTest is Test {
    ComputeSafeRecoveryCalldataScript private target;

    function setUp() public {
        target = new ComputeSafeRecoveryCalldataScript();
    }

    /**
     * @dev Helper function, sets environment variables.
     * @notice Manual environment variable setting is performed at the beginning of each test:
     * If an environment variable is set using vm.setEnv() inside a test case, it sets the variable
     * for all test cases. Unfortunately, the setUp() function does not reset the environment
     * variables before each test case (despite having vm.setEnv() calls). Therefore, if a test case
     * modifies an environment variable, subsequent test cases will use the  modified value instead
     * of the one set in the setUp() function. For more details, see the closed GitHub issue:
     * https://github.com/foundry-rs/foundry/issues/2349
     */
    function setEnvVars() public {
        vm.setEnv("OLD_OWNER", vm.toString(vm.addr(1234)));
        vm.setEnv("NEW_OWNER", vm.toString(vm.addr(5678)));
    }

    function test_RevertIf_NoOldOwnerEnv() public {
        setEnvVars();

        vm.setEnv("OLD_OWNER", "");

        vm.expectRevert(
            "vm.envAddress: failed parsing $OLD_OWNER as type `address`: parser error:\n$OLD_OWNER\n^\nexpected hex digits or the `0x` prefix for an empty hex string"
        );
        target.run();
    }

    function test_RevertIf_NoNewOwnerEnv() public {
        setEnvVars();

        vm.setEnv("NEW_OWNER", "");

        vm.expectRevert(
            "vm.envAddress: failed parsing $NEW_OWNER as type `address`: parser error:\n$NEW_OWNER\n^\nexpected hex digits or the `0x` prefix for an empty hex string"
        );
        target.run();
    }

    function test_SuccessfulComputation() public {
        setEnvVars();

        target.run();

        bytes memory recoveryCalldata = target.recoveryCalldata();

        require(recoveryCalldata.length > 0, "recoveryCalldata should not be empty");
    }
}
