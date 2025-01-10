// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Compute7579RecoveryDataHash } from "../Compute7579RecoveryDataHash.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract Compute7579RecoveryDataHashTest is BaseDeployTest {
    function setUp() public override {
        super.setUp();
    }

    function testRun() public {
        // Log the deployer's address and nonce before deployment
        address deployer = address(this);
        uint256 deployerNonce = vm.getNonce(deployer);
    
        // Compute the expected deployment address
        address expectedAddress = computeExpectedAddress(deployer, deployerNonce);
    
        // Deploy the contract
        Compute7579RecoveryDataHash target = new Compute7579RecoveryDataHash();
    
        // Log the actual deployed address
        address actualAddress = address(target);
    
        // Assert the deployed address matches the expected address
        require(actualAddress == expectedAddress, "Deployed address mismatch");
    }
    
    /**
     * @dev Computes the expected deployment address for a given deployer and nonce.
     * @param deployer The address deploying the contract.
     * @param nonce The nonce of the deployer at the time of deployment.
     * @return The expected deployment address.
     */
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
