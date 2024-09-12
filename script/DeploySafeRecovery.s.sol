// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { Verifier } from "ether-email-auth/src/utils/Verifier.sol";
import { Groth16Verifier } from "ether-email-auth/src/utils/Groth16Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from "ether-email-auth/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "ether-email-auth/src/EmailAuth.sol";

import { Safe7579 } from "safe7579/Safe7579.sol";
import { Safe7579Launchpad } from "safe7579/Safe7579Launchpad.sol";
import { IERC7484 } from "safe7579/interfaces/IERC7484.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// 1. `source .env`
// 2. `forge script --chain sepolia script/DeploySafeRecovery.s.sol:DeploySafeRecovery_Script
// --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv`
contract DeploySafeRecovery_Script is Script {
    function run() public {
        address entryPoint = address(0x0000000071727De22E5E9d8BAf0edAc6f37da032);
        IERC7484 registry = IERC7484(0xe0cde9239d16bEf05e62Bbf7aA93e420f464c826);

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address verifier = vm.envOr("VERIFIER", address(0));
        address dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        address dkimRegistrySigner = vm.envOr("SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));

        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        if (verifier == address(0)) {
            Verifier verifierImpl = new Verifier();
            console.log("Verifier implementation deployed at: %s", address(verifierImpl));
            Groth16Verifier groth16Verifier = new Groth16Verifier();
            ERC1967Proxy verifierProxy = new ERC1967Proxy(
                address(verifierImpl),
                abi.encodeCall(verifierImpl.initialize, (initialOwner, address(groth16Verifier)))
            );
            verifier = address(Verifier(address(verifierProxy)));
            vm.setEnv("VERIFIER", vm.toString(address(verifier)));
            console.log("Deployed Verifier at", verifier);
        }

        if (dkimRegistry == address(0)) {
            require(dkimRegistrySigner != address(0), "DKIM_REGISTRY_SIGNER is required");

            ECDSAOwnedDKIMRegistry dkimImpl = new ECDSAOwnedDKIMRegistry();
            console.log("ECDSAOwnedDKIMRegistry implementation deployed at: %s", address(dkimImpl));
            ERC1967Proxy dkimProxy = new ERC1967Proxy(
                address(dkimImpl),
                abi.encodeCall(dkimImpl.initialize, (initialOwner, dkimRegistrySigner))
            );
            dkimRegistry = address(ECDSAOwnedDKIMRegistry(address(dkimProxy)));
            vm.setEnv("ECDSA_DKIM", vm.toString(address(dkimRegistry)));
            console.log("Deployed DKIM Registry at", dkimRegistry);
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        EmailRecoveryUniversalFactory factory =
            new EmailRecoveryUniversalFactory(verifier, emailAuthImpl);
        (address module, address commandHandler) = factory.deployUniversalEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(SafeRecoveryCommandHandler).creationCode,
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
