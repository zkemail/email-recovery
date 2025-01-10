// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployUniversalEmailRecoveryModuleScript } from "../DeployUniversalEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { console } from "forge-std/console.sol";

/// @title DeployUniversalEmailRecoveryModule_Test
/// @notice Contains tests for deploying the Universal Email Recovery Module
contract DeployUniversalEmailRecoveryModule_Test is BaseDeployTest {
    /// @notice Tests the standard deployment run
    function test_run() public {
        BaseDeployTest.setUp();

        // Get deployer address and nonce before deployment
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        // Compute expected address
        address expectedAddress = computeExpectedAddress(deployer, deployerNonce);

        // Deploy the contract
        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        // Verify the deployed address
        address actualAddress = address(target);
        require(actualAddress == expectedAddress, "Deployed address mismatch");
    }

    /// @notice Tests the deployment run without a verifier
    function test_run_no_verifier() public {
        BaseDeployTest.setUp();
        vm.setEnv("VERIFIER", vm.toString(address(0)));

        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        address expectedAddress = computeExpectedAddress(deployer, deployerNonce);

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        address actualAddress = address(target);
        require(actualAddress == expectedAddress, "Deployed address mismatch");
    }

    /// @notice Tests the deployment run without a DKIM registry
    function test_run_no_dkim_registry() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);

        address expectedAddress = computeExpectedAddress(deployer, deployerNonce);

        DeployUniversalEmailRecoveryModuleScript target =
            new DeployUniversalEmailRecoveryModuleScript();
        target.run();

        address actualAddress = address(target);
        require(actualAddress == expectedAddress, "Deployed address mismatch");
    }

    /// @notice Computes the expected address for the deployed contract
    /// @param deployer The address deploying the contract
    /// @param nonce The nonce of the deployer at the time of deployment
    /// @return The computed address
    function computeExpectedAddress(address deployer, uint256 nonce)
        internal
        pure
        returns (address)
    {
        bytes memory data;
        if (nonce == 0x00) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80));
        } else if (nonce <= 0x7f) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce)));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), bytes1(uint8(nonce)));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), bytes2(uint16(nonce)));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), bytes3(uint24(nonce)));
        } else {
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), bytes4(uint32(nonce)));
        }

        return address(uint160(uint256(keccak256(data))));
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
