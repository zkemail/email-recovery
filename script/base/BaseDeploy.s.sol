// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";

abstract contract BaseDeployScript is Script {
    error MissingRequiredParameter(string param);

    struct DeploymentConfig {
        bytes32 create2Salt;
        uint256 dkimDelay;
        uint256 minimumDelay;
        uint256 privateKey;
        address commandHandler;
        address dkimRegistry;
        address dkimSigner;
        address emailAuthImpl;
        address killSwitchAuthorizer;
        address recoveryFactory;
        address validator;
        address verifier;
        address zkVerifier;
    }

    DeploymentConfig internal config;

    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    // ### PRIVATE HELPER FUNCTIONS ###

    /**
     * @dev Loads the deployment configuration from the environment variables.
     */
    function loadConfig() private {
        config = DeploymentConfig({
            create2Salt: bytes32(vm.envOr("CREATE2_SALT", uint256(0))),
            dkimDelay: vm.envOr("DKIM_DELAY", uint256(0)),
            minimumDelay: vm.envOr("MINIMUM_DELAY", uint256(0)),
            privateKey: vm.envOr("PRIVATE_KEY", uint256(0)),
            commandHandler: vm.envOr("COMMAND_HANDLER", address(0)),
            dkimRegistry: vm.envOr("DKIM_REGISTRY", address(0)),
            dkimSigner: vm.envOr("DKIM_SIGNER", address(0)),
            emailAuthImpl: vm.envOr("EMAIL_AUTH_IMPL", address(0)),
            killSwitchAuthorizer: vm.envOr("KILL_SWITCH_AUTHORIZER", address(0)),
            recoveryFactory: vm.envOr("RECOVERY_FACTORY", address(0)),
            validator: vm.envOr("VALIDATOR", address(0)),
            verifier: vm.envOr("VERIFIER", address(0)),
            zkVerifier: vm.envOr("ZK_VERIFIER", address(0))
        });
    }

    /**
     * @dev Validates the deployment configuration, reverting if any required parameter is missing.
     */
    function validateConfig() private view {
        if (config.privateKey == 0) {
            revert MissingRequiredParameter("PRIVATE_KEY");
        }

        if (config.killSwitchAuthorizer == address(0)) {
            revert MissingRequiredParameter("KILL_SWITCH_AUTHORIZER");
        }

        if (config.dkimRegistry == address(0) && config.dkimSigner == address(0)) {
            revert MissingRequiredParameter("DKIM_REGISTRY/DKIM_SIGNER");
        }
    }

    /**
     * @dev Helper function, deploys a UserOverrideableDKIMRegistry contract and then deploys a
     * proxy contract for it.
     * @return proxy The address of the UserOverrideableDKIMRegistry proxy contract.
     */
    function deployDkimRegistry() private returns (address proxy) {
        address initialOwner = vm.addr(config.privateKey);

        address dkim = address(new UserOverrideableDKIMRegistry{ salt: config.create2Salt }());
        console.log("UserOverrideableDKIMRegistry implementation deployed at: %s", dkim);

        proxy = address(
            new ERC1967Proxy{ salt: config.create2Salt }(
                address(dkim),
                abi.encodeCall(
                    UserOverrideableDKIMRegistry(dkim).initialize,
                    (initialOwner, config.dkimSigner, config.dkimDelay)
                )
            )
        );
        console.log("UserOverrideableDKIMRegistry proxy deployed at: %s", proxy);
    }

    /**
     * @dev Helper function, deploys an EmailAuth contract.
     * @return emailAuthImpl The address of the EmailAuth contract.
     */
    function deployEmailAuthImpl() private returns (address emailAuthImpl) {
        emailAuthImpl = address(new EmailAuth{ salt: config.create2Salt }());
        console.log("Deployed Email Auth at", emailAuthImpl);
    }

    // ### INTERNAL HELPER FUNCTIONS ###

    /**
     * @dev Helper function, deploys a Verifier contract and a Groth16Verifier contract, and then
     * deploys a proxy contract for it.
     * @return proxy The address of the Verifier proxy contract.
     */
    function deployVerifier() internal returns (address proxy) {
        address initialOwner = vm.addr(config.privateKey);

        address verifier = address(new Verifier{ salt: config.create2Salt }());
        console.log("Deployed Verifier implementation at: %s", address(verifier));

        address groth16 = address(new Groth16Verifier{ salt: config.create2Salt }());
        console.log("Deployed Groth16Verifier implementation at: %s", groth16);

        proxy = address(
            new ERC1967Proxy{ salt: config.create2Salt }(
                verifier, abi.encodeCall(Verifier(verifier).initialize, (initialOwner, groth16))
            )
        );
        console.log("Deployed Verifier proxy at: %s", proxy);
    }

    // ### VIRTUAL FUNCTIONS ###

    function deploy() internal virtual {
        if (config.dkimRegistry == address(0)) config.dkimRegistry = deployDkimRegistry();
        if (config.emailAuthImpl == address(0)) config.emailAuthImpl = deployEmailAuthImpl();
    }

    function run() public virtual {
        loadConfig();
        validateConfig();
    }
}
