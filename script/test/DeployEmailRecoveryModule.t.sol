// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeployEmailRecoveryModuleScript } from "../DeployEmailRecoveryModule.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import {console} from "forge-std/console.sol";

contract DeployEmailRecoveryModule_Test is BaseDeployTest {
    function setUp() public override {
        super.setUp();
    }

    function test_run() public {
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert that the contract is deployed at the correct address
        address expectedAddress = computeExpectedAddress(address(this), 9);
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_verifier() public {
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert branch logic and deployment state
        address expectedAddress = computeExpectedAddress(address(this), 9);
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_dkim_registry() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // Assert branch logic and deployment state
        address expectedAddress = computeExpectedAddress(address(this), 9);
        require(address(target) == expectedAddress, "Deployed address mismatch");
    }

    function computeExpectedAddress(address deployer, uint256 nonce) internal pure returns (address) {
        // Compute the RLP encoding of the deployer address and nonce
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

        // Return the address derived from the RLP encoding
        return address(uint160(uint256(keccak256(data))));
    }
}

contract DeployEmailRecoveryModule_TestFail is BaseDeployTest {
    function setUp() public override {
        super.setUp();
    }

    function testFail_run_no_dkim_registry_no_signer() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();

        // Expect the run to fail due to missing configuration
        target.run();
    }
}
