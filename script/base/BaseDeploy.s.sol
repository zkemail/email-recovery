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
    error InvalidCommandHandlerType();

    enum CommandHandlerType {
        Unset,
        AccountHidingRecovery,
        EmailRecovery,
        SafeRecovery
    }

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

    DeploymentConfig public config;

    address public emailRecoveryModule;
    address public emailRecoveryHandler;

    function run() public virtual {
        loadConfig();
        validateConfig();
    }

    function loadConfig() public {
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

    function validateConfig() public view {
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
     * Helper function to deploy a Verifier
     */
    function deployVerifier(address initialOwner, bytes32 salt) public returns (address) {
        Verifier verifierImpl = new Verifier{ salt: salt }();
        console.log("Verifier implementation deployed at: %s", address(verifierImpl));
        Groth16Verifier groth16Verifier = new Groth16Verifier{ salt: salt }();
        ERC1967Proxy verifierProxy = new ERC1967Proxy{ salt: salt }(
            address(verifierImpl),
            abi.encodeCall(verifierImpl.initialize, (initialOwner, address(groth16Verifier)))
        );
        address verifier = address(Verifier(address(verifierProxy)));
        console.log("Deployed Verifier at", verifier);
        return verifier;
    }

    /**
     * Helper function to deploy a UserOverrideableDKIMRegistry
     */
    function deployUserOverrideableDKIMRegistry(
        address initialOwner,
        address dkimRegistrySigner,
        uint256 setTimeDelay,
        bytes32 salt
    )
        public
        returns (address)
    {
        require(dkimRegistrySigner != address(0), "DKIM_SIGNER is required");
        UserOverrideableDKIMRegistry overrideableDkimImpl =
            new UserOverrideableDKIMRegistry{ salt: salt }();
        console.log(
            "UserOverrideableDKIMRegistry implementation deployed at: %s",
            address(overrideableDkimImpl)
        );
        ERC1967Proxy dkimProxy = new ERC1967Proxy{ salt: salt }(
            address(overrideableDkimImpl),
            abi.encodeCall(
                overrideableDkimImpl.initialize, (initialOwner, dkimRegistrySigner, setTimeDelay)
            )
        );
        address dkim = address(dkimProxy);
        console.log("UserOverrideableDKIMRegistry proxy deployed at: %s", dkim);
        return dkim;
    }

    function deployDKIMRegistry() internal {
        address initialOwner = vm.addr(config.privateKey);
        config.dkimRegistry = deployUserOverrideableDKIMRegistry(
            initialOwner, config.dkimSigner, config.dkimDelay, config.create2Salt
        );
    }

    function deployEmailAuth() internal {
        config.emailAuthImpl = address(new EmailAuth{ salt: config.create2Salt }());
        console.log("Deployed Email Auth at", config.emailAuthImpl);
    }

    function deployVerifier() internal {
        address initialOwner = vm.addr(config.privateKey);
        config.verifier = deployVerifier(initialOwner, config.create2Salt);
    }

    function deploy() internal virtual {
        if (config.dkimRegistry == address(0)) deployDKIMRegistry();
        if (config.emailAuthImpl == address(0)) deployEmailAuth();
    }
}
