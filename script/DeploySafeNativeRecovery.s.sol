// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract DeploySafeNativeRecoveryScript is BaseDeployScript {
    uint256 private privateKey;
    uint256 private create2Salt;
    uint256 private dkimDelay;
    uint256 private minimumDelay;
    address private killSwitchAuthorizer;
    address private dkimSigner;

    address private zkVerifier;
    address private dkimRegistry;
    address private emailAuthImpl;
    address private commandHandler;

    address public module;

    function loadEnvVars() private {
        // revert if not set
        privateKey = vm.envUint("PRIVATE_KEY");
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        // default to uint256(0) if not set
        create2Salt = vm.envOr("CREATE2_SALT", uint256(0));
        dkimDelay = vm.envOr("DKIM_DELAY", uint256(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));

        // default to address(0) if not set
        dkimSigner = vm.envOr("DKIM_SIGNER", address(0));
        zkVerifier = vm.envOr("ZK_VERIFIER", address(0));
        dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        commandHandler = vm.envOr("COMMAND_HANDLER", address(0));

        // other reverts
        if (dkimRegistry == address(0)) {
            require(dkimSigner != address(0), "DKIM_REGISTRY or DKIM_SIGNER is required");
        }
    }

    function run() public override {
        super.run();

        loadEnvVars();
        vm.startBroadcast(privateKey);

        address initialOwner = vm.addr(privateKey);

        console.log("verifier %s", zkVerifier);
        if (zkVerifier == address(0)) {
            zkVerifier = super.deployVerifier(initialOwner, create2Salt);
        }

        if (dkimRegistry == address(0)) {
            dkimRegistry = super.deployUserOverrideableDKIMRegistry(
                initialOwner, dkimSigner, dkimDelay, create2Salt
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(create2Salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        if (commandHandler == address(0)) {
            commandHandler = address(new SafeRecoveryCommandHandler{ salt: bytes32(create2Salt) }());
            console.log("Deployed Command Handler at", commandHandler);
        }

        module = address(
            new SafeEmailRecoveryModule{ salt: bytes32(create2Salt) }(
                zkVerifier,
                dkimRegistry,
                emailAuthImpl,
                commandHandler,
                minimumDelay,
                killSwitchAuthorizer
            )
        );

        console.log("Deployed Email Recovery Module at  ", vm.toString(module));

        vm.stopBroadcast();
    }
}
