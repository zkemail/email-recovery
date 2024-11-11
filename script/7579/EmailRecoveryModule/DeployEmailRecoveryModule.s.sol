// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { BaseDeployScript } from "../../BaseDeployScript.s.sol";

contract DeployEmailRecoveryModuleScript is BaseDeployScript {
    address verifier;
    address dkim;
    address emailAuthImpl;
    address commandHandler;
    uint256 minimumDelay;
    address killSwitchAuthorizer;
    address validatorAddr;

    address initialOwner;
    address dkimRegistrySigner;
    uint256 dkimDelay;
    uint256 salt;

    function run() public override {
        super.run();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        verifier = vm.envOr("VERIFIER", address(0));
        dkim = vm.envOr("DKIM_REGISTRY", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        commandHandler = vm.envOr("COMMAND_HANDLER", address(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");
        validatorAddr = vm.envOr("VALIDATOR", address(0));

        initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        dkimDelay = vm.envOr("DKIM_DELAY", uint256(0));
        salt = vm.envOr("CREATE2_SALT", uint256(0));

        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, salt);
        }

        // Deploy Useroverridable DKIM registry
        if (dkim == address(0)) {
            dkim = deployUserOverrideableDKIMRegistry(
                initialOwner, dkimRegistrySigner, dkimDelay, salt
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("EmailAuth implementation deployed at", emailAuthImpl);
        }

        if (validatorAddr == address(0)) {
            validatorAddr = address(new OwnableValidator{ salt: bytes32(salt) }());
            console.log("OwnableValidator deployed at", validatorAddr);
        }

        address _factory = vm.envOr("RECOVERY_FACTORY", address(0));
        if (_factory == address(0)) {
            _factory =
                address(new EmailRecoveryFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl));
            console.log("EmailRecoveryFactory deployed at", _factory);
        }

        EmailRecoveryFactory factory = EmailRecoveryFactory(_factory);
        (address module, address commandHandler) = factory.deployEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(EmailRecoveryCommandHandler).creationCode,
            minimumDelay,
            killSwitchAuthorizer,
            address(dkim),
            validatorAddr,
            bytes4(keccak256(bytes("changeOwner(address)")))
        );

        console.log("EmailRecoveryModule deployed at", vm.toString(module));
        console.log("EmailRecoveryCommandHandler deployed at", vm.toString(commandHandler));
        vm.stopBroadcast();
    }
}
