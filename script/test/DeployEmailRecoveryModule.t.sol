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
    // In forge scripts the following deterministic deployer address is used for deployments.
    // See Foundry Book: https://book.getfoundry.sh/tutorials/create2-tutorial#introduction
    // This address is used to calculate the deployment address of a contract.
    address constant CREATE2_DEPLOYER_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    /**
     * @dev Sets up the test environment.
     */
    function setUp() public override {
        super.setUp();
    }

    function isContractDeployed(address addr) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return size > 0;
    }

    /**
     * @dev Tests the deployment process when the VERIFIER environment variable is not set.
     * @notice It is expected from the script to deploy a new verifier proxy to the calculated address.
     */
    function test_run_no_verifier(uint256 salt) public {
        // saving the previous verifier address for reset
        address prevVerifier = vm.envOr("VERIFIER", address(0));
        // clearing the VERIFIER environment variable
        vm.setEnv("VERIFIER", "");
        // setting fuzz value
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        // args used during the verifier deployment
        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        // computing implementation address
        bytes memory iBytecode = type(Verifier).creationCode;
        address implementation = Create2.computeAddress(
            bytes32(salt),
            keccak256(iBytecode),
            CREATE2_DEPLOYER_ADDRESS
        );

        // computing Groth16Verifier address
        bytes memory gBytecode = type(Groth16Verifier).creationCode;
        address groth16Verifier = Create2.computeAddress(
            bytes32(salt),
            keccak256(gBytecode),
            CREATE2_DEPLOYER_ADDRESS
        );

        // computing proxy address
        bytes memory pBytecode = type(ERC1967Proxy).creationCode;
        bytes memory pArgs = abi.encode(
            implementation,
            abi.encodeCall(
                Verifier(implementation).initialize,
                (initialOwner,
                address(groth16Verifier))
            )
        );
        bytes memory pFullBytecode = abi.encodePacked(pBytecode, pArgs);
        address proxy = Create2.computeAddress(
            bytes32(salt),
            keccak256(pFullBytecode),
            CREATE2_DEPLOYER_ADDRESS
        );

        // making sure the contract is not yet deployed
        require(!isContractDeployed(proxy), "verifier should not be deployed");

        // executing the script
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // checking state changes
        require(isContractDeployed(proxy), "verifier proxy should be deployed");
        require(target.verifier() == proxy, "verifier() should return the proxy address");

        // reset the VERIFIER environment variable
        vm.setEnv("VERIFIER", vm.toString(prevVerifier));
    }

    /**
     * @dev Tests the deployment process when the DKIM_REGISTRY environment variable is not set.
     * @notice It is expected from the script to deploy a new dkim proxy to the calculated address.
     */
    function test_run_no_dkim_registry(uint256 salt, uint256 setTimeDelay) public {
        // saving the previous env vars for reset
        address prevDkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        uint256 prevSetTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
        // clearing the DKIM_REGISTRY environment variable
        vm.setEnv("DKIM_REGISTRY", "");
        // setting fuzz values
        vm.setEnv("DKIM_DELAY", vm.toString(setTimeDelay));
        vm.setEnv("CREATE2_SALT", vm.toString(salt));

        // args used during the dkim deployment
        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        address dkimRegistrySigner = vm.envAddress("DKIM_SIGNER");

        // computing implementation address
        address implementation = Create2.computeAddress(
            bytes32(salt),
            keccak256(type(UserOverrideableDKIMRegistry).creationCode),
            CREATE2_DEPLOYER_ADDRESS
        );

        // computing proxy address
        bytes memory pBytecode = type(ERC1967Proxy).creationCode;
        bytes memory pArgs = abi.encode(
            implementation,
            abi.encodeCall(
                UserOverrideableDKIMRegistry(implementation).initialize,
                (initialOwner,
                dkimRegistrySigner,
                setTimeDelay)
            )
        );
        bytes memory pFullBytecode = abi.encodePacked(pBytecode, pArgs);
        address proxy = Create2.computeAddress(
            bytes32(salt),
            keccak256(pFullBytecode),
            CREATE2_DEPLOYER_ADDRESS
        );

        // making sure the contract is not yet deployed
        require(!isContractDeployed(proxy), "dkim should not be deployed");

        // running the script
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // checking the state changes
        require(isContractDeployed(proxy), "dkim should be deployed");

        // check the state changes
        require(address(target.dkim()) == proxy, "dkim should return the proxy address");

        // reset the env vars
        vm.setEnv("DKIM_REGISTRY", vm.toString(prevDkimRegistry));
        vm.setEnv("DKIM_DELAY", vm.toString(prevSetTimeDelay));
    }

    /**
     * @dev Tests the deployment process when the EMAIL_AUTH_IMPL environment variable is not set.
     * @notice It is expected from the script to deploy a new email auth implementation to the calculated address.
     */
    function test_run_no_email_auth_impl(uint256 salt) public {
        // saving env var for reset
        address prevEmailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        // clearing the EMAIL_AUTH_IMPL environment variable
        vm.setEnv("EMAIL_AUTH_IMPL", "");
        // setting fuzz value
        vm.setEnv("CREATE2_SALT", vm.toString(salt));

        // computing implementation address
        bytes memory bytecode = type(EmailAuth).creationCode;
        bytes32 bytecodeHash = keccak256(bytecode);
        address implementation = Create2.computeAddress(
            bytes32(salt),
            bytecodeHash,
            CREATE2_DEPLOYER_ADDRESS
        );

        // making sure the contract is not yet deployed
        require(!isContractDeployed(implementation), "email auth should not be deployed");

        // running the script
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // checking the state changes
        require(isContractDeployed(implementation), "email auth should be deployed");
        require(target.emailAuthImpl() == implementation, "email auth should return the implementation address");

        // reset env var
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(prevEmailAuthImpl));
    }

    /**
     * @dev Tests the deployment process when the VALIDATOR environment variable is not set.
     * @notice It is expected from the script to deploy a new validator implementation to the calculated address.
     */
    function test_run_no_validator(uint256 salt) public {
        // saving env var for reset
        address prevValidator = vm.envOr("VALIDATOR", address(0));
        // clearing the VALIDATOR environment variable
        vm.setEnv("VALIDATOR", "");
        // setting fuzz value
        vm.setEnv("CREATE2_SALT", vm.toString(salt));

        // computing implementation address
        bytes memory bytecode = type(OwnableValidator).creationCode;
        bytes32 bytecodeHash = keccak256(bytecode);
        address implementation = Create2.computeAddress(
            bytes32(salt),
            bytecodeHash,
            CREATE2_DEPLOYER_ADDRESS
        );

        // making sure the contract is not yet deployed
        require(!isContractDeployed(implementation), "validator should not be deployed");

        // running the script
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // checking the state changes
        require(isContractDeployed(implementation), "validator should be deployed");

        // check the state changes
        require(target.validatorAddr() == implementation, "validator should return the implementation address");

        // reset env var
        vm.setEnv("VALIDATOR", vm.toString(prevValidator));
    }

    /**
     * @dev Tests the deployment process when the RECOVERY_FACTORY environment variable is not set.
     * @notice It is expected from the script to deploy a new recovery factory to the calculated address.
     */
    function test_run_no_recovery_factory(uint256 salt) public {
        // saving env var for reset
        address prevRecoveryFactory = vm.envOr("RECOVERY_FACTORY", address(0));
        // clearing the RECOVERY_FACTORY environment variable
        vm.setEnv("RECOVERY_FACTORY", "");
        // setting fuzz value
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        // args used during the recovery factory deployment
        address verifier = vm.envAddress("VERIFIER");
        address emailAuthImpl = vm.envAddress("EMAIL_AUTH_IMPL");

        // computing implementation address
        bytes memory bytecode = type(EmailRecoveryFactory).creationCode;
        bytes memory constructorArgs = abi.encode(verifier, emailAuthImpl);
        bytes memory fullBytecode = abi.encodePacked(bytecode, constructorArgs);
        address implementation = Create2.computeAddress(
            bytes32(salt),
            keccak256(fullBytecode),
            CREATE2_DEPLOYER_ADDRESS
        );

        // making sure the contract is not yet deployed
        require(!isContractDeployed(implementation), "recovery factory should not be deployed");

        // running the script
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // checking the state changes
        require(isContractDeployed(implementation), "recovery factory should be deployed");

        // reset env var
        vm.setEnv("RECOVERY_FACTORY", vm.toString(prevRecoveryFactory));
    }

    /**
     * @dev Tests that the standard deployment process executes correctly.
     * @notice It is expected from the script to deploy recovery module and command handler to the calculated addresses.
     */
    function test_run(uint256 salt, uint256 minimumDelay) public {
        // saving env vars for reset
        address prevRecoveryFactory = vm.envOr("RECOVERY_FACTORY", address(0));
        uint256 prevMinimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        // setting fuzz values
        vm.setEnv("CREATE2_SALT", vm.toString(salt));
        vm.setEnv("MINIMUM_DELAY", vm.toString(minimumDelay));
        
        // pre deploy recovery factory
        address recoveryFactory = address(new EmailRecoveryFactory{ salt: bytes32(salt) }(vm.envAddress("VERIFIER"), vm.envAddress("EMAIL_AUTH_IMPL")));
        vm.setEnv("RECOVERY_FACTORY", vm.toString(recoveryFactory));

        // computing command handler address
        bytes32 commandHandlerBytecodeHash = keccak256(type(EmailRecoveryCommandHandler).creationCode);
        address commandHandlerAddress = Create2.computeAddress(bytes32(uint256(0)), commandHandlerBytecodeHash, recoveryFactory);

        // computing recovery module address
        bytes memory rmBytecode = type(EmailRecoveryModule).creationCode;
        bytes memory rmBytecodeArgs = abi.encode(
            vm.envAddress("VERIFIER"),
            vm.envAddress("DKIM_REGISTRY"),
            vm.envAddress("EMAIL_AUTH_IMPL"),
            commandHandlerAddress,
            minimumDelay,
            vm.envAddress("KILL_SWITCH_AUTHORIZER"),
            vm.envAddress("VALIDATOR"),
            bytes4(keccak256(bytes("changeOwner(address)")))
        );
        bytes memory rmFullBytecode = abi.encodePacked(rmBytecode, rmBytecodeArgs);
        address recoveryModuleAddress = Create2.computeAddress(bytes32(uint256(0)), keccak256(rmFullBytecode), recoveryFactory);

        // making sure contracts are not yet deployed
        require(!isContractDeployed(commandHandlerAddress), "commandHandler should not be deployed");
        require(!isContractDeployed(recoveryModuleAddress), "recoveryModule should not be deployed");
        
        // running the script
        DeployEmailRecoveryModuleScript target = new DeployEmailRecoveryModuleScript();
        target.run();

        // checking the state changes
        require(isContractDeployed(commandHandlerAddress), "commandHandler should be deployed");
        require(isContractDeployed(recoveryModuleAddress), "recoveryModule should be deployed");

        // reset env var
        vm.setEnv("RECOVERY_FACTORY", vm.toString(prevRecoveryFactory));
        vm.setEnv("MINIMUM_DELAY", vm.toString(prevMinimumDelay));
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
