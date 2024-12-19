// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeploySafeRecovery_Script} from "../../script/DeploySafeRecovery.s.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {SafeRecovery} from "../../src/SafeRecovery.sol";
import {UserOverrideableDKIMRegistry} from "../../src/UserOverrideableDKIMRegistry.sol";
import {Verifier} from "../../src/Verifier.sol";

contract DeploySafeRecoveryTest is Test {
    DeploySafeRecovery_Script deployer;
    
    function setUp() public {
        deployer = new DeploySafeRecovery_Script();
    }

    function testFreshDeployment() public {
        // Setup
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(address(1)));
        
        // Run deployment
        deployer.run();
        
        // Assert contract deployments
        assertTrue(address(deployer.verifier()).code.length > 0);
        assertTrue(address(deployer.dkim()).code.length > 0);
        assertTrue(address(deployer.recovery()).code.length > 0);
        
        // Assert initialization states
        assertEq(deployer.dkim().owner(), deployer.initialOwner());
        assertEq(deployer.recovery().owner(), deployer.initialOwner());
        
        // Assert recovery module configuration
        SafeRecovery recovery = deployer.recovery();
        assertEq(recovery.verifier(), address(deployer.verifier()));
        assertEq(recovery.dkimRegistry(), address(deployer.dkim()));
    }

    function testExistingContractsDeployment() public {
        // Setup existing contracts
        address mockVerifier = makeAddr("verifier");
        address mockDkim = makeAddr("dkim");
        vm.etch(mockVerifier, bytes("mock code"));
        vm.etch(mockDkim, bytes("mock code"));
        vm.setEnv("VERIFIER", vm.toString(mockVerifier));
        vm.setEnv("DKIM_REGISTRY", vm.toString(mockDkim));
        
        // Run deployment
        deployer.run();
        
        // Assert existing contracts were used
        assertEq(address(deployer.verifier()), mockVerifier);
        assertEq(address(deployer.dkim()), mockDkim);
        
        // Assert only recovery was deployed
        assertTrue(address(deployer.recovery()).code.length > 0);
    }
} 