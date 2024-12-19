// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {DeployEmailRecoveryModule_Script} from "../../script/DeployEmailRecoveryModule.s.sol";
import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";
import {EmailRecoveryModule} from "../../src/EmailRecoveryModule.sol";
import {UserOverrideableDKIMRegistry} from "../../src/UserOverrideableDKIMRegistry.sol";
import {Verifier} from "../../src/Verifier.sol";

contract DeployEmailRecoveryModuleTest is Test {
    DeployEmailRecoveryModule_Script deployer;
    
    function setUp() public {
        deployer = new DeployEmailRecoveryModule_Script();
    }

    function testFreshDeployment() public {
        // Setup
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(address(1)));
        
        // Run deployment
        deployer.run();
        
        // Assert contract deployments
        assertTrue(address(deployer.verifier()).code.length > 0);
        assertTrue(address(deployer.dkim()).code.length > 0);
        assertTrue(address(deployer.module()).code.length > 0);
        
        // Assert initialization states
        assertEq(deployer.dkim().owner(), deployer.initialOwner());
        
        // Assert module configuration
        EmailRecoveryModule module = deployer.module();
        assertEq(module.verifier(), address(deployer.verifier()));
        assertEq(module.dkimRegistry(), address(deployer.dkim()));
    }

    function testPartialExistingDeployment() public {
        // Setup existing verifier
        address mockVerifier = makeAddr("verifier");
        vm.etch(mockVerifier, bytes("mock code"));
        vm.setEnv("VERIFIER", vm.toString(mockVerifier));
        
        // Run deployment
        deployer.run();
        
        // Assert verifier wasn't redeployed
        assertEq(address(deployer.verifier()), mockVerifier);
        
        // Assert new contracts were deployed
        assertTrue(address(deployer.dkim()).code.length > 0);
        assertTrue(address(deployer.module()).code.length > 0);
    }
} 