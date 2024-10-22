// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeploySafeNativeRecovery_Script is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address verifier = vm.envOr("ZK_VERIFIER", address(0));
        address dkimRegistrySigner = vm.envOr("DKIM_REGISTRY_SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        address commandHandler = vm.envOr("COMMAND_HANDLER", address(0));

        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        uint salt = vm.envOr("CREATE2_SALT", uint(0));

        console.log("salt %s", salt);

        console.log("verifier %s", verifier);

        UserOverrideableDKIMRegistry dkim;

        if (verifier == address(0)) {
            Verifier verifierImpl = new Verifier{ salt: bytes32(salt) }();
            console.log("Verifier implementation deployed at: %s", address(verifierImpl));
            Groth16Verifier groth16Verifier = new Groth16Verifier{ salt: bytes32(salt) }();
            ERC1967Proxy verifierProxy = new ERC1967Proxy{ salt: bytes32(salt) }(
                address(verifierImpl),
                abi.encodeCall(verifierImpl.initialize, (initialOwner, address(groth16Verifier)))
            );
            verifier = address(Verifier(address(verifierProxy)));
            vm.setEnv("VERIFIER", vm.toString(address(verifier)));
            console.log("Deployed Verifier at", verifier);
        }

        // Deploy Useroverridable DKIM registry
        dkim = UserOverrideableDKIMRegistry(vm.envOr("DKIM_REGISTRY", address(0)));
        uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
        if (address(dkim) == address(0)) {
            require(dkimRegistrySigner != address(0), "DKIM_REGISTRY_SIGNER is required");
            UserOverrideableDKIMRegistry overrideableDkimImpl = new UserOverrideableDKIMRegistry{ salt: bytes32(salt) }();
            console.log(
                "UserOverrideableDKIMRegistry implementation deployed at: %s",
                address(overrideableDkimImpl)
            );
            ERC1967Proxy dkimProxy = new ERC1967Proxy{ salt: bytes32(salt) }(
                address(overrideableDkimImpl),
                abi.encodeCall(
                    overrideableDkimImpl.initialize,
                    (initialOwner, dkimRegistrySigner, setTimeDelay)
                )
            );
            dkim = UserOverrideableDKIMRegistry(address(dkimProxy));
            vm.setEnv("DKIM_REGISTRY", vm.toString(address(dkim)));
            console.log("UseroverrideableDKIMRegistry proxy deployed at: %s", address(dkim));
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        if (commandHandler == address(0)) {
            commandHandler = address(new SafeRecoveryCommandHandler{ salt: bytes32(salt) }());
            console.log("Deployed Command Handler at", commandHandler);
        }

        address module = address(
            new SafeEmailRecoveryModule{ salt: bytes32(salt) }(verifier, address(dkim), emailAuthImpl, commandHandler)
        );

        console.log("Deployed Email Recovery Module at  ", vm.toString(module));

        vm.stopBroadcast();
    }
}
