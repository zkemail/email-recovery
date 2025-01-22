// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Compute7579RecoveryDataHashScript } from "../Compute7579RecoveryDataHash.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

/**
 * @title Compute7579RecoveryDataHashTest
 * @dev Test contract for the script that computes 7579 recovery data and hash.
 *
 * @notice Manual environment variable reset is performed at the beginning of each test to address
 * the following issue:
 * If an environment variable is set using vm.setEnv() inside a test case, it sets the variable for
 * all test cases. Unfortunately, the setUp() function does not reset the environment variables
 * before each test case (despite having vm.setEnv() calls). Therefore, if a test case modifies an
 * environment variable, subsequent test cases will use the  modified value instead of the one set
 * in the setUp() function. For more details, see the closed GitHub issue:
 * https://github.com/foundry-rs/foundry/issues/2349
 *
 */
contract Compute7579RecoveryDataHashTest is BaseDeployTest {
    Compute7579RecoveryDataHashScript target;
    bytes4 constant CHANGE_OWNER_SELECTOR = bytes4(keccak256(bytes("changeOwner(address)")));

    function setUp() public override {
        super.setUp();
        target = new Compute7579RecoveryDataHashScript();
    }

    function test_RevertIf_NoValidatorEnv() public {
        resetAllEnv();

        vm.setEnv("VALIDATOR", "");

        vm.expectRevert(
            "vm.envAddress: failed parsing $VALIDATOR as type `address`: parser error:\n$VALIDATOR\n^\nexpected hex digits or the `0x` prefix for an empty hex string"
        );
        target.run();
    }

    function test_RevertIf_NoNewOwnerEnv() public {
        resetAllEnv();

        vm.setEnv("NEW_OWNER", "");

        vm.expectRevert(
            "vm.envAddress: failed parsing $NEW_OWNER as type `address`: parser error:\n$NEW_OWNER\n^\nexpected hex digits or the `0x` prefix for an empty hex string"
        );
        target.run();
    }

    function test_SuccessfulComputation() public {
        resetAllEnv();

        target.run();

        bytes memory recoveryData = target.recoveryData();
        bytes32 recoveryDataHash = target.recoveryDataHash();

        require(recoveryData.length > 0, "recoveryData should not be empty");
        require(recoveryDataHash != 0, "recoveryDataHash should not be 0");
    }
}
