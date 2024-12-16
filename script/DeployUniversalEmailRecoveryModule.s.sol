// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";
import { SafeSingletonDeployer } from "safe-singleton-deployer/SafeSingletonDeployer.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployUniversalEmailRecoveryModuleScript is BaseDeployScript {
    function run() public override {
        super.run();
        address verifier = vm.envOr("VERIFIER", address(0));
        address dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        uint256 minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        address killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        uint256 salt = vm.envOr("CREATE2_SALT", uint256(0));
        UserOverrideableDKIMRegistry dkim;

        if (verifier == address(0)) {
            address verifierImpl = SafeSingletonDeployer.broadcastDeploy(
                initialOwner, // any private key will do
                type(Verifier).creationCode,
                abi.encode(),
                keccak256("VERIFIER")
            );
            console.log("Verifier implementation deployed at: %s", address(verifierImpl));
            address groth16Verifier = SafeSingletonDeployer.broadcastDeploy(
                initialOwner, // any private key will do
                type(Groth16Verifier).creationCode,
                abi.encode(),
                keccak256("GROTH16_VERIFIER")
            );
            address verifierProxy = SafeSingletonDeployer.broadcastDeploy(
                initialOwner, // any private key will do
                type(ERC1967Proxy).creationCode,
                abi.encode(
                    address(verifierImpl),
                    abi.encodeCall(
                        Verifier(verifierImpl).initialize, (initialOwner, address(groth16Verifier))
                    )
                ),
                keccak256("VERIFIER_PROXY")
            );
            verifier = address(Verifier(address(verifierProxy)));
            console.log("Deployed Verifier at", verifier);
        }

        // Deploy Useroverridable DKIM registry
        dkim = UserOverrideableDKIMRegistry(vm.envOr("DKIM_REGISTRY", address(0)));
        uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
        if (address(dkim) == address(0)) {
            address userOverrideableDkimImpl = SafeSingletonDeployer.broadcastDeploy(
                initialOwner, // any private key will do
                type(UserOverrideableDKIMRegistry).creationCode,
                abi.encode(),
                keccak256("USER_OVERRIDEABLE_DKIM_IMPL")
            );
            console.log(
                "UserOverrideableDKIMRegistry implementation deployed at: %s",
                address(userOverrideableDkimImpl)
            );
            {
                address dkimProxy = SafeSingletonDeployer.broadcastDeploy(
                    initialOwner, // any private key will do
                    type(ERC1967Proxy).creationCode,
                    abi.encode(
                        address(userOverrideableDkimImpl),
                        abi.encodeCall(
                            UserOverrideableDKIMRegistry(userOverrideableDkimImpl).initialize,
                            (initialOwner, dkimRegistrySigner, setTimeDelay)
                        )
                    ),
                    keccak256("USER_OVERRIDEABLE_DKIM_PROXY")
                );
                dkim = UserOverrideableDKIMRegistry(dkimProxy);
            }
            console.log("UseroverrideableDKIMRegistry proxy deployed at: %s", address(dkim));
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = SafeSingletonDeployer.broadcastDeploy(
                initialOwner, // any private key will do
                type(EmailAuth).creationCode,
                abi.encode(),
                keccak256("EMAIL_AUTH_IMPL")
            );
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        address _factory = vm.envOr("RECOVERY_FACTORY", address(0));
        if (_factory == address(0)) {
            _factory = address(
                new EmailRecoveryUniversalFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl)
            );
            console.log("Deployed Email Recovery Factory at", _factory);
        }
        {
            EmailRecoveryUniversalFactory factory = EmailRecoveryUniversalFactory(_factory);
            (address module, address commandHandler) = factory.deployUniversalEmailRecoveryModule(
                bytes32(uint256(0)),
                bytes32(uint256(0)),
                type(EmailRecoveryCommandHandler).creationCode,
                minimumDelay,
                killSwitchAuthorizer,
                address(dkim)
            );

            console.log("Deployed Email Recovery Module at", vm.toString(module));
            console.log("Deployed Email Recovery Handler at", vm.toString(commandHandler));
        }
    }
}
