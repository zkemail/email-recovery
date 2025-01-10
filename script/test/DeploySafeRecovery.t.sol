// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeNativeRecovery_Script } from "../DeploySafeNativeRecovery.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { console } from "forge-std/console.sol";

contract DeploySafeNativeRecovery_Test is BaseDeployTest {
    function test_run() public {
        BaseDeployTest.setUp();
        uint256 deployerNonce = vm.getNonce(address(this));
        address expectedAddress = computeExpectedAddress(address(this), deployerNonce);

        // Deploy the contract
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        // Verify the deployed address
        address actualAddress = address(target);
        require(actualAddress == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_verifier() public {
        BaseDeployTest.setUp();
        vm.setEnv("ZK_VERIFIER", vm.toString(address(0)));

        uint256 deployerNonce = vm.getNonce(address(this));
        address expectedAddress = computeExpectedAddress(address(this), deployerNonce);

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        address actualAddress = address(target);
        require(actualAddress == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_dkim_registry() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        uint256 deployerNonce = vm.getNonce(address(this));
        address expectedAddress = computeExpectedAddress(address(this), deployerNonce);

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        address actualAddress = address(target);
        require(actualAddress == expectedAddress, "Deployed address mismatch");
    }

    function test_run_no_signer() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));

        uint256 deployerNonce = vm.getNonce(address(this));
        address expectedAddress = computeExpectedAddress(address(this), deployerNonce);

        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();

        address actualAddress = address(target);
        require(actualAddress == expectedAddress, "Deployed address mismatch");
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

contract DeploySafeNativeRecovery_TestFail is BaseDeployTest {
    function testFail_run_no_dkim_registry_no_signer() public {
        BaseDeployTest.setUp();
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();

        target.run();
    }
}
