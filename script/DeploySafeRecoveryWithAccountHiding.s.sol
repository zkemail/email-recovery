// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";

import { Safe7579 } from "safe7579/Safe7579.sol";
import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { IERC7484 } from "safe7579/interfaces/IERC7484.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";

// 1. `source .env`
// 2. `forge script
// script/DeploySafeRecoveryWithAccountHiding.s.sol:DeploySafeRecoveryWithAccountHiding_Script
// --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`
contract DeploySafeRecoveryWithAccountHiding_Script is Script {
    function run() public {
        address entryPoint = address(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        IERC7484 registry = IERC7484(0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address verifier = address(0);
        address dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        address dkimRegistrySigner = vm.envOr("SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        uint256 minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));

        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        uint salt = vm.envOr("CREATE2_SALT", uint(0));

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

        if (dkimRegistry == address(0)) {
            require(dkimRegistrySigner != address(0), "DKIM_REGISTRY_SIGNER is required");
            // Deploy Useroverridable DKIM registry
            uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
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
            dkimRegistry = address(UserOverrideableDKIMRegistry(address(dkimProxy)));
            vm.setEnv("DKIM_REGISTRY", vm.toString(dkimRegistry));
            console.log("UseroverrideableDKIMRegistry proxy deployed at: %s", dkimRegistry);
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        EmailRecoveryUniversalFactory factory =
            new EmailRecoveryUniversalFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl);
        (address module, address commandHandler) = factory.deployUniversalEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(AccountHidingRecoveryCommandHandler).creationCode,
            minimumDelay,
            dkimRegistry
        );

        address safe7579 = address(new Safe7579{ salt: bytes32(uint256(0)) }());
        address safe7579Launchpad =
            address(new Safe7579Launchpad{ salt: bytes32(uint256(0)) }(entryPoint, registry));

        console.log("Deployed Email Recovery Module at  ", vm.toString(module));
        console.log("Deployed Email Recovery Handler at ", vm.toString(commandHandler));
        console.log("Deployed Safe 7579 at              ", vm.toString(safe7579));
        console.log("Deployed Safe 7579 Launchpad at    ", vm.toString(safe7579Launchpad));

        vm.stopBroadcast();
    }
}