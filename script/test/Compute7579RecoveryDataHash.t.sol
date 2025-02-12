// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Test } from "forge-std/Test.sol";
import { Compute7579RecoveryDataHashScript } from "../Compute7579RecoveryDataHash.s.sol";

contract Compute7579RecoveryDataHashTest is Test {
    address private envNewOwner;
    address private envValidator;

    Compute7579RecoveryDataHashScript private target;

    function setUp() public {
        envNewOwner = vm.addr(1234);
        envValidator = vm.addr(5678);

        target = new Compute7579RecoveryDataHashScript();
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
    function setEnvVars() private {
        vm.setEnv("VALIDATOR", vm.toString(envValidator));
        vm.setEnv("NEW_OWNER", vm.toString(envNewOwner));
    }

    function test_RevertIf_NoValidatorEnv() public {
        setEnvVars();

        vm.setEnv("VALIDATOR", "");

        vm.expectRevert(
            abi.encodePacked(
                "vm.envAddress: failed parsing $VALIDATOR as type `address`: parser error:\n",
                "$VALIDATOR\n",
                "^\n",
                "expected hex digits or the `0x` prefix for an empty hex string"
            )
        );
        target.run();
    }

    function test_RevertIf_NoNewOwnerEnv() public {
        setEnvVars();

        vm.setEnv("NEW_OWNER", "");

        vm.expectRevert(
            abi.encodePacked(
                "vm.envAddress: failed parsing $NEW_OWNER as type `address`: parser error:\n",
                "$NEW_OWNER\n",
                "^\n",
                "expected hex digits or the `0x` prefix for an empty hex string"
            )
        );
        target.run();
    }

    function test_SuccessfulComputation() public {
        setEnvVars();

        bytes memory changeOwnerCalldata =
            abi.encodeWithSelector(bytes4(keccak256("changeOwner(address)")), envNewOwner);
        bytes memory expectedData = abi.encode(envValidator, changeOwnerCalldata);
        bytes32 expectedHash = keccak256(expectedData);

        target.run();

        assertEq(keccak256(target.recoveryData()), expectedHash);
        assertEq(target.recoveryDataHash(), expectedHash);
    }
}
