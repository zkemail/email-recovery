// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { BaseDeployScript } from "../../BaseDeployScript.s.sol";

contract DeployEmailRecoveryModuleScript is BaseDeployScript {
    address public verifier;
    address public dkim;
    address public emailAuthImpl;
    uint256 public minimumDelay;
    address public killSwitchAuthorizer;
    address public validatorAddr;
    address public factory;

    address public initialOwner;
    address public dkimRegistrySigner;
    uint256 public dkimDelay;
    uint256 public salt;

    function run() public override {
        super.run();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        verifier = vm.envOr("VERIFIER", address(0));
        dkim = vm.envOr("DKIM_REGISTRY", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");
        validatorAddr = vm.envOr("VALIDATOR", address(0));
        factory = vm.envOr("RECOVERY_FACTORY", address(0));

        initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        dkimDelay = vm.envOr("DKIM_DELAY", uint256(0));
        salt = vm.envOr("CREATE2_SALT", uint256(0));

        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, salt);
        }

        if (dkim == address(0)) {
            dkim = deployUserOverrideableDKIMRegistry(
                initialOwner, dkimRegistrySigner, dkimDelay, salt
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("EmailAuth implemenation deployed at", emailAuthImpl);
        }

        if (validatorAddr == address(0)) {
            validatorAddr = address(new OwnableValidator{ salt: bytes32(salt) }());
            console.log("OwnableValidator deployed at", validatorAddr);
        }

        if (factory == address(0)) {
            factory =
                address(new EmailRecoveryFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl));
            console.log("EmailRecoveryFactory deployed at", factory);
        }

        EmailRecoveryFactory emailRecoveryFactory = EmailRecoveryFactory(factory);
        (address module, address commandHandler) = emailRecoveryFactory.deployEmailRecoveryModule(
            bytes32(uint256(0)),
            bytes32(uint256(0)),
            type(AccountHidingRecoveryCommandHandler).creationCode,
            minimumDelay,
            killSwitchAuthorizer,
            address(dkim),
            validatorAddr,
            bytes4(keccak256(bytes("changeOwner(address)")))
        );

        console.log("EmailRecoveryModule deployed at", vm.toString(module));
        console.log("AccountHidingRecoveryCommandHandler deployed at", vm.toString(commandHandler));
        vm.stopBroadcast();
    }
}
