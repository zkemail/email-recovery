// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeploySafeNativeRecovery_Script} from "../../script/DeploySafeNativeRecovery.s.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {SafeNativeRecovery} from "../../src/SafeNativeRecovery.sol";
import {UserOverrideableDKIMRegistry} from "../../src/UserOverrideableDKIMRegistry.sol";
import {Verifier} from "../../src/Verifier.sol";

contract DeploySafeNativeRecoveryTest is Test {
    DeploySafeNativeRecovery_Script deployer;
    
    function setUp() public {
        deployer = new DeploySafeNativeRecovery_Script();
    }

    function testFreshDeployment() public {
        // Setup
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(address(1)));
        
        // Calculate expected addresses
        bytes32 salt = bytes32(0);
        address expectedVerifier = _computeCreate2Address(
            salt,
            keccak256(type(Verifier).creationCode)
        );
        
        // Run deployment
        deployer.run();
        
        // Assert contract deployments
        assertTrue(address(deployer.verifier()).code.length > 0, "Verifier not deployed");
        assertTrue(address(deployer.dkim()).code.length > 0, "DKIM registry not deployed");
        assertTrue(address(deployer.recovery()).code.length > 0, "Recovery not deployed");
        
        // Assert addresses match computed ones
        assertEq(address(deployer.verifier()), expectedVerifier, "Verifier address mismatch");
        
        // Assert initialization states
        assertEq(deployer.dkim().owner(), deployer.initialOwner());
        assertEq(deployer.recovery().owner(), deployer.initialOwner());
    }

    function testExistingVerifierDeployment() public {
        // Setup existing verifier
        address mockVerifier = makeAddr("verifier");
        vm.etch(mockVerifier, bytes("mock code"));
        vm.setEnv("VERIFIER", vm.toString(mockVerifier));
        
        // Run deployment
        deployer.run();
        
        // Assert verifier wasn't redeployed
        assertEq(address(deployer.verifier()), mockVerifier);
        
        // Assert other contracts were deployed
        assertTrue(address(deployer.dkim()).code.length > 0);
        assertTrue(address(deployer.recovery()).code.length > 0);
    }

    function _computeCreate2Address(
        bytes32 salt,
        bytes32 bytecodeHash
    ) internal view returns (address) {
        return Create2.computeAddress(
            salt,
            bytecodeHash,
            address(this)
        );
    }
} 