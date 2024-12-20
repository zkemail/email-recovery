// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeNativeRecovery_Script } from "../DeploySafeNativeRecovery.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Safe7579 } from "safe7579/Safe7579.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";

contract DeploySafeNativeRecovery_Test is BaseDeployTest {
    DeploySafeNativeRecovery_Script target;
    address payable expectedSafe;
    address expectedEmailAuth;
    address expectedModule;

    function setUp() public override {
        super.setUp();
        target = new DeploySafeNativeRecovery_Script();
        
        // Calculate expected addresses
        bytes32 salt = bytes32(vm.envOr("ACCOUNT_SALT", uint256(0)));
        expectedSafe = payable(Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(Safe7579).creationCode)),
            address(this)
        ));
        expectedEmailAuth = Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(EmailAuth).creationCode)),
            address(this)
        );
    }

    function test_run() public {
        uint256 snapshot = vm.snapshot();
        
        // Run deployment
        target.run();
        
        // Assert Safe deployment and configuration
        assertHasBytecode(expectedSafe, "Safe not deployed");
        Safe7579 safe = Safe7579(expectedSafe);
       
        
        // Assert EmailAuth deployment and configuration
        assertHasBytecode(expectedEmailAuth, "EmailAuth not deployed");
        EmailAuth auth = EmailAuth(expectedEmailAuth);
        assertEq(auth.verifierAddr(), vm.envAddress("ZK_VERIFIER"), "Verifier mismatch");
        assertEq(auth.dkimRegistryAddr(), vm.envAddress("DKIM_REGISTRY"), "DKIM registry mismatch");
        
        
        vm.revertTo(snapshot);
    }

    function test_run_no_verifier() public {
        uint256 snapshot = vm.snapshot();
        
        // Record initial state
        address initialVerifier = vm.envAddress("ZK_VERIFIER");
        vm.setEnv("ZK_VERIFIER", vm.toString(address(0)));
        
        target.run();
        
        // Assert new verifier was deployed
        address newVerifier = vm.envAddress("ZK_VERIFIER");
        assertTrue(newVerifier != address(0), "No verifier deployed");
        assertTrue(newVerifier != initialVerifier, "Verifier not updated");
        assertHasBytecode(newVerifier, "Verifier has no code");
        
        // Assert EmailAuth uses new verifier
        EmailAuth auth = EmailAuth(expectedEmailAuth);
        assertEq(auth.verifierAddr(), newVerifier, "EmailAuth not using new verifier");
        
        vm.revertTo(snapshot);
    }

    function test_run_no_dkim_registry() public {
        uint256 snapshot = vm.snapshot();
        
        // Record initial state
        address initialRegistry = vm.envAddress("DKIM_REGISTRY");
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        
        target.run();
        
        // Assert new registry was deployed
        address newRegistry = vm.envAddress("DKIM_REGISTRY");
        assertTrue(newRegistry != address(0), "No registry deployed");
        assertTrue(newRegistry != initialRegistry, "Registry not updated");
        assertHasBytecode(newRegistry, "Registry has no code");
        
        // Assert EmailAuth uses new registry
        EmailAuth auth = EmailAuth(expectedEmailAuth);
        assertEq(auth.dkimRegistryAddr(), newRegistry, "EmailAuth not using new registry");
        
        vm.revertTo(snapshot);
    }

    function test_run_no_signer() public {
        uint256 snapshot = vm.snapshot();
        
        address initialSigner = vm.envAddress("DKIM_SIGNER");
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        
        target.run();
        
        // Assert signer was updated
        address newSigner = vm.envAddress("DKIM_SIGNER");
        assertTrue(newSigner != initialSigner, "Signer not updated");
        
        vm.revertTo(snapshot);
    }

    // Helper function to check contract deployment
    function assertHasBytecode(address _contract, string memory message) internal {
        assertTrue(_contract.code.length > 0, message);
    }
}

contract DeploySafeNativeRecovery_TestFail is BaseDeployTest {
    function testFail_run_no_dkim_registry_no_signer() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }

    function testFail_invalid_owner() public {
        vm.setEnv("NEW_OWNER", vm.toString(address(0)));
        
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }

    function testFail_invalid_validator() public {
        vm.setEnv("VALIDATOR", vm.toString(address(0)));
        
        DeploySafeNativeRecovery_Script target = new DeploySafeNativeRecovery_Script();
        target.run();
    }
}
