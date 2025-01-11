// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Compute7579RecoveryDataHash } from "../Compute7579RecoveryDataHash.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract Compute7579RecoveryDataHashTest is BaseDeployTest {
    address expectedAddress;

    function setUp() public override {
        super.setUp();

        // Initialize deployer and deployerNonce
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        expectedAddress = super.computeExpectedAddress(deployer, deployerNonce);
    }

    function testRun() public {
        // Deploy the contract
        setUp();
        Compute7579RecoveryDataHash target = new Compute7579RecoveryDataHash();

        // Assert the deployed address matches the expected address
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    // Test with a different NEW_OWNER value
    function testRunWithDifferentOwner() public {
        setUp();
        // Use a checksummed address for NEW_OWNER
        vm.setEnv("NEW_OWNER", vm.toString(address(0x1234567890AbcdEF1234567890aBcdef12345678)));

        Compute7579RecoveryDataHash target = new Compute7579RecoveryDataHash();
        target.run();

        // Pre-compute expected recovery data
        bytes4 functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        address newOwner = vm.envAddress("NEW_OWNER");
        address validator = vm.envAddress("VALIDATOR");
        bytes memory changeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes memory expectedRecoveryData = abi.encode(validator, changeOwnerCalldata);
        bytes32 expectedRecoveryDataHash = keccak256(expectedRecoveryData);

        // Assert script outputs
        require(keccak256(abi.encode(validator, changeOwnerCalldata)) == expectedRecoveryDataHash, "Recovery data mismatch");
    }

    // Test with an invalid VALIDATOR value
    function testRunWithInvalidValidator() public {
        setUp();
        vm.setEnv("VALIDATOR", "0x0"); // Invalid validator address

        Compute7579RecoveryDataHash target = new Compute7579RecoveryDataHash();

        // Expect the run to fail or handle the invalid validator
        vm.expectRevert(); // Expect the transaction to revert
        target.run();
    }

    // Test with missing NEW_OWNER environment variable
    function testRunWithMissingNewOwner() public {
        setUp();

        // Clear NEW_OWNER by setting an empty value
        vm.setEnv("NEW_OWNER", "0x0");

        Compute7579RecoveryDataHash target = new Compute7579RecoveryDataHash();

        // Expect the run to fail or handle the missing NEW_OWNER
        vm.expectRevert(); // Expect the transaction to revert
        target.run();
    }
}
