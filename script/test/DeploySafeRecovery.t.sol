// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { DeploySafeRecovery_Script } from "../DeploySafeRecovery.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Safe7579 } from "safe7579/Safe7579.sol";
import { EmailRecoveryModule } from "../../src/modules/EmailRecoveryModule.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";

contract DeploySafeRecovery_Test is BaseDeployTest {
    DeploySafeRecovery_Script target;
    address payable expectedSafe;
    address expectedModule;
    address expectedVerifier;
    address expectedDKIMRegistry;

    function setUp() public override {
        super.setUp();
        target = new DeploySafeRecovery_Script();
        
        // Calculate expected addresses
        bytes32 salt = bytes32(vm.envOr("ACCOUNT_SALT", uint256(0)));
        expectedSafe = payable(Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(Safe7579).creationCode)),
            address(this)
        ));
        
        expectedModule = Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(EmailRecoveryModule).creationCode)),
            address(this)
        );
        
        expectedVerifier = Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(Verifier).creationCode)),
            address(this)
        );
        
        expectedDKIMRegistry = Create2.computeAddress(
            salt,
            keccak256(abi.encodePacked(type(UserOverrideableDKIMRegistry).creationCode)),
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
        
        // Assert Module deployment and configuration
        assertHasBytecode(expectedModule, "Module not deployed");
        EmailRecoveryModule module = EmailRecoveryModule(expectedModule);
        assertEq(module.verifier(), vm.envAddress("VERIFIER"), "Module verifier mismatch");
        
        vm.revertTo(snapshot);
    }

    function test_run_no_verifier() public {
        uint256 snapshot = vm.snapshot();
        
        // Record initial state
        address initialVerifier = vm.envAddress("VERIFIER");
        vm.setEnv("VERIFIER", vm.toString(address(0)));
        
        target.run();
        
        // Assert new verifier deployment
        address newVerifier = vm.envAddress("VERIFIER");
        assertTrue(newVerifier != address(0), "No verifier deployed");
        assertTrue(newVerifier != initialVerifier, "Verifier not updated");
        assertHasBytecode(newVerifier, "Verifier has no code");
        
        // Assert module configuration
        EmailRecoveryModule module = EmailRecoveryModule(expectedModule);
        assertEq(module.verifier(), newVerifier, "Module not using new verifier");
        
        vm.revertTo(snapshot);
    }

    function test_run_no_dkim_registry() public {
        uint256 snapshot = vm.snapshot();
        
        // Record initial state
        address initialRegistry = vm.envAddress("DKIM_REGISTRY");
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        
        target.run();
        
        // Assert new registry deployment
        address newRegistry = vm.envAddress("DKIM_REGISTRY");
        assertTrue(newRegistry != address(0), "No registry deployed");
        assertTrue(newRegistry != initialRegistry, "Registry not updated");
        assertHasBytecode(newRegistry, "Registry has no code");
        
        // Assert module configuration
        EmailRecoveryModule module = EmailRecoveryModule(expectedModule);
       
        
        vm.revertTo(snapshot);
    }

    function test_run_with_existing_contracts() public {
        uint256 snapshot = vm.snapshot();
        
        // Setup mock existing contracts
        address mockVerifier = makeAddr("mockVerifier");
        address mockRegistry = makeAddr("mockRegistry");
        vm.etch(mockVerifier, bytes("mock code"));
        vm.etch(mockRegistry, bytes("mock code"));
        
        vm.setEnv("VERIFIER", vm.toString(mockVerifier));
        vm.setEnv("DKIM_REGISTRY", vm.toString(mockRegistry));
        
        target.run();
        
        // Assert existing contracts were used
        EmailRecoveryModule module = EmailRecoveryModule(expectedModule);
        assertEq(module.verifier(), mockVerifier, "Module not using existing verifier");
        
        vm.revertTo(snapshot);
    }

    function testFail_run_invalid_owner() public {
        vm.setEnv("NEW_OWNER", vm.toString(address(0)));
        target.run();
    }

    function testFail_run_invalid_validator() public {
        vm.setEnv("VALIDATOR", vm.toString(address(0)));
        target.run();
    }

    function testFail_run_invalid_kill_switch() public {
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(address(0)));
        target.run();
    }

    // Helper function to check contract deployment
    function assertHasBytecode(address _contract, string memory message) internal {
        assertTrue(_contract.code.length > 0, message);
    }
}
