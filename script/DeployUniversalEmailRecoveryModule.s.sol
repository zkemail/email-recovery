// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { SafeSingletonDeployer } from "safe-singleton-deployer/SafeSingletonDeployer.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script } from "forge-std/Script.sol";

contract DeployUniversalEmailRecoveryModuleScript is Script {
    uint256 deployer = vm.envUint("DEPLOYER");
    address initialOwner = vm.envAddress("INITIAL_OWNER");
    address verifier = vm.envOr("VERIFIER", address(0));
    address dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
    address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
    uint256 minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));

    function run() public {
        // Deploy verifier if not provided
        if (verifier == address(0)) {
            verifier = deployVerifierContracts();
        }

        // Deploy DKIM registry if not provided
        UserOverrideableDKIMRegistry dkim =
            UserOverrideableDKIMRegistry(vm.envOr("DKIM_REGISTRY", address(0)));
        if (address(dkim) == address(0)) {
            dkim = deployDKIMRegistry();
        }

        // Deploy EmailAuth if not provided
        if (emailAuthImpl == address(0)) {
            emailAuthImpl = SafeSingletonDeployer.broadcastDeploy(
                deployer, type(EmailAuth).creationCode, abi.encode(), keccak256("EMAIL_AUTH_IMPL")
            );
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        // Deploy and configure factory
        address factory = deployAndConfigureFactory(address(dkim));

        // Deploy recovery module and handler
        deployRecoveryContracts(factory, address(dkim));
    }

    function deployVerifierContracts() private returns (address) {
        address verifierImpl = SafeSingletonDeployer.broadcastDeploy(
            deployer, type(Verifier).creationCode, abi.encode(), keccak256("VERIFIER")
        );
        console.log("Verifier implementation deployed at: %s", address(verifierImpl));

        address groth16Verifier = SafeSingletonDeployer.broadcastDeploy(
            deployer,
            type(Groth16Verifier).creationCode,
            abi.encode(),
            keccak256("GROTH16_VERIFIER")
        );

        address verifierProxy = SafeSingletonDeployer.broadcastDeploy(
            deployer,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                address(verifierImpl),
                abi.encodeCall(Verifier(verifierImpl).initialize, (initialOwner, groth16Verifier))
            ),
            keccak256("VERIFIER_PROXY")
        );

        address verifier = address(Verifier(verifierProxy));
        console.log("Deployed Verifier at", verifier);
        return verifier;
    }

    function deployDKIMRegistry() private returns (UserOverrideableDKIMRegistry) {
        uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));

        address impl = SafeSingletonDeployer.broadcastDeploy(
            deployer,
            type(UserOverrideableDKIMRegistry).creationCode,
            abi.encode(),
            keccak256("USER_OVERRIDEABLE_DKIM_IMPL")
        );
        console.log("UserOverrideableDKIMRegistry implementation deployed at: %s", address(impl));

        address proxy = SafeSingletonDeployer.broadcastDeploy(
            deployer,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                address(impl),
                abi.encodeCall(
                    UserOverrideableDKIMRegistry(impl).initialize,
                    (initialOwner, dkimRegistrySigner, setTimeDelay)
                )
            ),
            keccak256("USER_OVERRIDEABLE_DKIM_PROXY")
        );

        UserOverrideableDKIMRegistry dkim = UserOverrideableDKIMRegistry(proxy);
        console.log("UseroverrideableDKIMRegistry proxy deployed at: %s", address(dkim));
        return dkim;
    }

    function deployAndConfigureFactory(address dkim) private returns (address) {
        address factory = vm.envOr("RECOVERY_FACTORY", address(0));
        if (factory == address(0)) {
            factory = SafeSingletonDeployer.broadcastDeploy(
                deployer,
                type(EmailRecoveryUniversalFactory).creationCode,
                abi.encode(verifier, emailAuthImpl),
                keccak256("EMAIL_RECOVERY_FACTORY")
            );
            console.log("Deployed Email Recovery Factory at", factory);
        }
        return factory;
    }

    function deployRecoveryContracts(address factory, address dkim) private {
        EmailRecoveryUniversalFactory recoveryFactory = EmailRecoveryUniversalFactory(factory);
        (address module, address commandHandler) = recoveryFactory
            .deployUniversalEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(EmailRecoveryCommandHandler).creationCode,
            minimumDelay,
            initialOwner,
            dkim
        );

        console.log("Deployed Email Recovery Module at", vm.toString(module));
        console.log("Deployed Email Recovery Handler at", vm.toString(commandHandler));
    }
}
