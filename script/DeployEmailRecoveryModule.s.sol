// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { Verifier } from "ether-email-auth/packages/contracts/src/utils/Verifier.sol";
import { ECDSAOwnedDKIMRegistry } from
    "ether-email-auth/packages/contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployEmailRecoveryModuleScript is Script {
    function run() public {
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        address verifier = vm.envOr("VERIFIER", address(0));
        address dkimRegistry = vm.envOr("DKIM_REGISTRY", address(0));
        address dkimRegistrySigner = vm.envOr("SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        address validatorAddr = vm.envOr("VALIDATOR", address(0));

        address initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));

        if (verifier == address(0)) {
            Verifier verifierImpl = new Verifier();
            console.log("Verifier implementation deployed at: %s", address(verifierImpl));
            ERC1967Proxy verifierProxy = new ERC1967Proxy(
                address(verifierImpl), abi.encodeCall(verifierImpl.initialize, (initialOwner))
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

        if (validatorAddr == address(0)) {
            validatorAddr = address(new OwnableValidator());
            console.log("Deployed Ownable Validator at", validatorAddr);
        }

        EmailRecoverySubjectHandler emailRecoveryHandler = new EmailRecoverySubjectHandler();

        address _factory = vm.envOr("RECOVERY_FACTORY", address(0));
        if (_factory == address(0)) {
            _factory = address(new EmailRecoveryFactory(verifier, emailAuthImpl));
            console.log("Deployed Email Recovery Factory at", _factory);
        }
        {
            EmailRecoveryFactory factory = EmailRecoveryFactory(_factory);
            (address module, address subjectHandler) = factory.deployEmailRecoveryModule(
                bytes32(uint256(0)),
                bytes32(uint256(0)),
                type(EmailRecoverySubjectHandler).creationCode,
                dkimRegistry,
                validatorAddr,
                bytes4(keccak256(bytes("changeOwner(address)")))
            );

            console.log("Deployed Email Recovery Module at", vm.toString(module));
            console.log("Deployed Email Recovery Handler at", vm.toString(subjectHandler));
            vm.stopBroadcast();
        }
    }
}
