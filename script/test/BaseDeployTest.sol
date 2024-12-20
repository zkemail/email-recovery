// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSAOwnedDKIMRegistry } from "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";

abstract contract BaseDeployTest is Test {
    // Expected addresses
    address internal expectedVerifier;
    address internal expectedDKIMRegistry;
    address internal expectedEmailAuth;
    address internal expectedCommandHandler;
    bytes32 internal salt;

    function setUp() public virtual {
        salt = bytes32(vm.envOr("CREATE2_SALT", uint256(0)));
        
        // Set environment variables
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(1)));
        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Calculate expected addresses
        expectedVerifier = computeCreate2Address(
            salt,
            keccak256(abi.encodePacked(type(Verifier).creationCode)),
            address(this)
        );

        expectedDKIMRegistry = computeCreate2Address(
            salt,
            keccak256(abi.encodePacked(type(ECDSAOwnedDKIMRegistry).creationCode)),
            address(this)
        );

        expectedEmailAuth = computeCreate2Address(
            salt,
            keccak256(abi.encodePacked(type(EmailAuth).creationCode)),
            address(this)
        );

        expectedCommandHandler = computeCreate2Address(
            salt,
            keccak256(abi.encodePacked(type(EmailRecoveryCommandHandler).creationCode)),
            address(this)
        );

        // Deploy Verifier and set up proxy
        address verifier = deployVerifier(initialOwner);

        // Set up additional environment variables
        setupEnvironmentVariables();

        // Deploy EmailRecoveryCommandHandler
        deployCommandHandler();

        // Deploy EmailRecoveryUniversalFactory and set up module
        deployEmailRecoveryModule(verifier);
    }

    function deployVerifier(address initialOwner) internal returns (address) {
        uint256 snapshot = vm.snapshot();
        
        Verifier verifierImpl = new Verifier{ salt: salt }();
        assertEq(address(verifierImpl), expectedVerifier, "Verifier address mismatch");
        
        Groth16Verifier groth16Verifier = new Groth16Verifier();
        ERC1967Proxy verifierProxy = new ERC1967Proxy(
            address(verifierImpl),
            abi.encodeCall(verifierImpl.initialize, (initialOwner, address(groth16Verifier)))
        );
        
        address verifier = address(Verifier(address(verifierProxy)));
        assertEq(Verifier(verifier).owner(), initialOwner, "Verifier owner mismatch");
        
        vm.setEnv("VERIFIER", vm.toString(address(verifierImpl)));
        
        vm.revertTo(snapshot);
        return verifier;
    }

    function setupEnvironmentVariables() internal {
        uint256 snapshot = vm.snapshot();
        
        // Set DKIM signer
        vm.setEnv("DKIM_SIGNER", vm.toString(vm.addr(5)));
        address dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        require(dkimRegistrySigner != address(0), "Invalid DKIM signer");

        // Deploy DKIM Registry and set up proxy
        address dkimRegistry = deployDKIMRegistry(dkimRegistrySigner);
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(dkimRegistry)));
        require(dkimRegistry != address(0), "DKIM registry deployment failed");

        // Set other environment variables
        vm.setEnv("MINIMUM_DELAY", vm.toString(uint256(0)));
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(vm.addr(1)));
        require(vm.envAddress("KILL_SWITCH_AUTHORIZER") != address(0), "Invalid kill switch authorizer");

        // Set EmailAuth implementation
        address emailAuthImpl = address(new EmailAuth{ salt: salt }());
        assertEq(emailAuthImpl, expectedEmailAuth, "EmailAuth address mismatch");
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(emailAuthImpl));

        // Set additional variables
        vm.setEnv("NEW_OWNER", vm.toString(vm.addr(8)));
        vm.setEnv("VALIDATOR", vm.toString(vm.addr(9)));
        vm.setEnv("ACCOUNT_SALT", vm.toString(bytes32(uint256(1))));
        
        vm.revertTo(snapshot);
    }

    function deployDKIMRegistry(address dkimRegistrySigner) internal returns (address) {
        uint256 snapshot = vm.snapshot();
        
        ECDSAOwnedDKIMRegistry dkimImpl = new ECDSAOwnedDKIMRegistry{ salt: salt }();
        assertEq(address(dkimImpl), expectedDKIMRegistry, "DKIM registry address mismatch");
        
        ERC1967Proxy dkimProxy = new ERC1967Proxy(
            address(dkimImpl),
            abi.encodeCall(
                dkimImpl.initialize,
                (vm.addr(vm.envUint("PRIVATE_KEY")), dkimRegistrySigner)
            )
        );
        
        address registry = address(ECDSAOwnedDKIMRegistry(address(dkimProxy)));
        assertEq(ECDSAOwnedDKIMRegistry(registry).owner(), vm.addr(vm.envUint("PRIVATE_KEY")), "DKIM registry owner mismatch");
        
        vm.revertTo(snapshot);
        return registry;
    }

    function deployCommandHandler() internal {
        uint256 snapshot = vm.snapshot();
        
        EmailRecoveryCommandHandler handler = new EmailRecoveryCommandHandler{ salt: salt }();
        assertEq(address(handler), expectedCommandHandler, "Command handler address mismatch");
        
        vm.revertTo(snapshot);
    }

    function deployEmailRecoveryModule(address verifier) internal {
        uint256 snapshot = vm.snapshot();
        
        address _factory = address(
            new EmailRecoveryUniversalFactory(verifier, vm.envAddress("EMAIL_AUTH_IMPL"))
        );
        
        EmailRecoveryUniversalFactory factory = EmailRecoveryUniversalFactory(_factory);
        (address module, address handler) = factory.deployUniversalEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(EmailRecoveryCommandHandler).creationCode,
            vm.envUint("MINIMUM_DELAY"),
            vm.envAddress("KILL_SWITCH_AUTHORIZER"),
            vm.envAddress("DKIM_REGISTRY")
        );
        
        require(module != address(0), "Module deployment failed");
        require(handler != address(0), "Handler deployment failed");
        
        vm.setEnv("RECOVERY_MODULE", vm.toString(module));
        
        vm.revertTo(snapshot);
    }

    // Helper function to compute Create2 addresses
    function computeCreate2Address(
        bytes32 _salt,
        bytes32 _bytecodeHash,
        address _deployer
    ) internal pure returns (address) {
        return Create2.computeAddress(_salt, _bytecodeHash, _deployer);
    }
}
