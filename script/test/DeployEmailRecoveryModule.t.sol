// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { BaseDeployTest } from "./BaseDeployTest.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { DeployEmailRecoveryModuleScript } from "../DeployEmailRecoveryModule.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Vm } from "forge-std/Vm.sol";

/**
 * @title DeployEmailRecoveryModule_Test
 * @dev Test contract for deploying the Email Recovery Module.
 * 
 * @notice Manual environment variable reset is performed at the end of each test to address the following issue:
 * If an environment variable is set using vm.setEnv() inside a test case, it sets the variable for all test cases. 
 * Unfortunately, the setUp() function does not reset the environment variables before each test case (despite having 
 * vm.setEnv() calls). Therefore, if a test case modifies an environment variable, subsequent test cases will use the 
 * modified value instead of the one set in the setUp() function. For more details, see the closed GitHub issue: 
 * https://github.com/foundry-rs/foundry/issues/2349
 * 
 */
contract DeployEmailRecoveryModule_Test is BaseDeployTest {

    /**
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        super.setUp();
    }


    function test_run_no_verifier(uint256 salt) public {
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        vm.setEnv("VERIFIER", "");
        
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        require(target.verifier() != address(0), "verifier not deployed");
    }

    function test_run_no_dkim_registry(uint256 salt, uint256 setTimeDelay) public {
        vm.setEnv("DKIM_REGISTRY", "");
        vm.setEnv("DKIM_DELAY", vm.toString(setTimeDelay));
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        require(address(target.dkim()) != address(0), "dkim not deployed");
    }

    function test_run_no_email_auth_impl(uint256 salt) public {        
        vm.setEnv("EMAIL_AUTH_IMPL", "");
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        require(target.emailAuthImpl() != address(0), "email auth not deployed");
    }

    function test_run_no_validator(uint256 salt) public {
        vm.setEnv("VALIDATOR", "");
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        require(target.validatorAddr() != address(0), "validator not deployed");
    }

    function test_run(uint256 salt, uint256 minimumDelay) public {
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        vm.setEnv("MINIMUM_DELAY", vm.toString(minimumDelay));
        
        vm.recordLogs();
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
        
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bool foundDeployEvent = false;
        for (uint i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("EmailRecoveryModuleDeployed(address,address,address,bytes4)")) {
                foundDeployEvent = true;
                break;
            }
        }
        assertTrue(foundDeployEvent, "EmailRecoveryModuleDeployed event not emitted");
    }
}

/**
 * @title DeployEmailRecoveryModule_TestFail
 * @dev Test contract for failure scenarios when deploying the Email Recovery Module
 */
contract DeployEmailRecoveryModule_TestFail is BaseDeployTest {
    /**
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        super.setUp();
    }

    /**
     * @dev Tests that deployment fails when both DKIM_REGISTRY and DKIM_SIGNER environment
     * variables are
     * not set.
     */
    function testFail_run_no_dkim_registry_no_signer() public {
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));
        vm.setEnv("DKIM_SIGNER", vm.toString(address(0)));
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();
    }
}
