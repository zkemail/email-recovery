// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/* solhint-disable no-console */

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";

abstract contract BaseDeployTest is Test {
    function setUp() public virtual {
        // Set environment variables
        vm.setEnv(
            "PRIVATE_KEY", "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        );
        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        // Deploy Verifier and set up proxy
        address verifier = deployVerifier(initialOwner);

        // Set up additional environment variables
        setupEnvironmentVariables();

        // Deploy EmailRecoveryCommandHandler
        new EmailRecoveryCommandHandler();

        // Deploy EmailRecoveryUniversalFactory and set up module
        deployEmailRecoveryModule(verifier);
    }

    /**
     * @dev Deploys the Verifier contract and sets up its proxy.
     * @param initialOwner The address of the initial owner.
     * @return The address of the deployed Verifier contract.
     */
    function deployVerifier(address initialOwner) internal returns (address) {
        Verifier verifierImpl = new Verifier();
        Groth16Verifier groth16Verifier = new Groth16Verifier();
        ERC1967Proxy verifierProxy = new ERC1967Proxy(
            address(verifierImpl),
            abi.encodeCall(verifierImpl.initialize, (initialOwner, address(groth16Verifier)))
        );
        address verifier = address(Verifier(address(verifierProxy)));
        vm.setEnv("VERIFIER", vm.toString(address(verifierImpl)));
        return verifier;
    }

    /**
     * @dev Sets up additional environment variables required for the deployment.
     */
    function setupEnvironmentVariables() internal {
        vm.setEnv("DKIM_REGISTRY_SIGNER", vm.toString(vm.addr(5)));
        address dkimRegistrySigner = vm.envOr("DKIM_REGISTRY_SIGNER", address(0));

        // Deploy DKIM Registry and set up proxy
        address dkimRegistry = deployDKIMRegistry(dkimRegistrySigner);
        vm.setEnv("DKIM_REGISTRY", vm.toString(address(dkimRegistry)));

        vm.setEnv("MINIMUM_DELAY", vm.toString(uint256(0)));
        vm.setEnv("KILL_SWITCH_AUTHORIZER", vm.toString(vm.addr(1)));

        // Set EmailAuth implementation address
        address emailAuthImpl = address(new EmailAuth());
        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(emailAuthImpl));

        // Set additional environment variables
        vm.setEnv("NEW_OWNER", vm.toString(vm.addr(8)));
        vm.setEnv("VALIDATOR", vm.toString(vm.addr(9)));
        vm.setEnv("ACCOUNT_SALT", vm.toString(bytes32(uint256(1))));
    }

    /**
     * @dev Deploys the ECDSAOwnedDKIMRegistry contract and sets up its proxy.
     * @param dkimRegistrySigner The address of the DKIM registry signer.
     * @return The address of the deployed DKIM Registry contract.
     */
    function deployDKIMRegistry(address dkimRegistrySigner) internal returns (address) {
        ECDSAOwnedDKIMRegistry dkimImpl = new ECDSAOwnedDKIMRegistry();
        console2.log("ECDSAOwnedDKIMRegistry implementation deployed at: %s", address(dkimImpl));
        ERC1967Proxy dkimProxy = new ERC1967Proxy(
            address(dkimImpl),
            abi.encodeCall(
                dkimImpl.initialize, (vm.addr(vm.envUint("PRIVATE_KEY")), dkimRegistrySigner)
            )
        );
        return address(ECDSAOwnedDKIMRegistry(address(dkimProxy)));
    }

    /**
     * @dev Deploys the EmailRecoveryUniversalFactory and sets up the recovery module.
     * @param verifier The address of the deployed Verifier contract.
     */
    function deployEmailRecoveryModule(address verifier) internal {
        address _factory =
            address(new EmailRecoveryUniversalFactory(verifier, vm.envAddress("EMAIL_AUTH_IMPL")));
        EmailRecoveryUniversalFactory factory = EmailRecoveryUniversalFactory(_factory);
        (address module,) = factory.deployUniversalEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(EmailRecoveryCommandHandler).creationCode,
            vm.envUint("MINIMUM_DELAY"),
            vm.envAddress("KILL_SWITCH_AUTHORIZER"),
            false,
            vm.envAddress("DKIM_REGISTRY")
        );
        vm.setEnv("RECOVERY_MODULE", vm.toString(module));
    }
}
