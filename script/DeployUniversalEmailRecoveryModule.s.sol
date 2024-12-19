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

contract DeployUniversalEmailRecoveryModuleScript is BaseDeployScript {
    function run() public override {
        super.run();
        vm.startBroadcast(vm.envUint("DEPLOYER"));
        address initialOwner = vm.envAddress("INITIAL_OWNER");
        address verifier = vm.envOr("VERIFIER", address(0));
        address dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        address emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        uint256 minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));

        UserOverrideableDKIMRegistry dkim;

        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, 0);
        }

        // Deploy Useroverridable DKIM registry
        dkim = UserOverrideableDKIMRegistry(vm.envOr("DKIM_REGISTRY", address(0)));
        uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
        if (address(dkim) == address(0)) {
            dkim = UserOverrideableDKIMRegistry(
                deployUserOverrideableDKIMRegistry(
                    initialOwner, dkimRegistrySigner, setTimeDelay, 0
                )
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = SafeSingletonDeployer.deploy(
                type(EmailAuth).creationCode, abi.encode(), keccak256("EMAIL_AUTH_IMPL")
            );
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        address _factory = vm.envOr("RECOVERY_FACTORY", address(0));
        if (_factory == address(0)) {
            _factory = SafeSingletonDeployer.deploy(
                type(EmailRecoveryUniversalFactory).creationCode,
                abi.encode(verifier, emailAuthImpl),
                keccak256("EMAIL_RECOVERY_FACTORY")
            );
            console.log("Deployed Email Recovery Factory at", _factory);
        }
        {
            address killSwitchAuthorizer = vm.envAddress("INITIAL_OWNER");
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
            vm.stopBroadcast();
        }
    }
}
