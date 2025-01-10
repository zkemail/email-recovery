// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console, gas-custom-errors */

import { console } from "forge-std/console.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { BaseDeployScript } from "./BaseDeployScript.s.sol";

contract DeployEmailRecoveryModuleScript is BaseDeployScript {
    address public verifier;
    address public dkimRegistrySigner;
    address public emailAuthImpl;
    address public eoaVerifier; /// @dev - This is originally come from the EOA-TX-builder module.
    address public eoaAuthImpl; /// @dev - This is originally come from the EOA-TX-builder module.
    address public validatorAddr;
    uint256 public minimumDelay;
    address public killSwitchAuthorizer;

    address public initialOwner;
    uint256 public salt;

    UserOverrideableDKIMRegistry public dkim;

    function run() public override {
        super.run();
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));
        verifier = vm.envOr("VERIFIER", address(0));
        dkimRegistrySigner = vm.envOr("DKIM_SIGNER", address(0));
        emailAuthImpl = vm.envOr("EMAIL_AUTH_IMPL", address(0));
        validatorAddr = vm.envOr("VALIDATOR", address(0));
        minimumDelay = vm.envOr("MINIMUM_DELAY", uint256(0));
        killSwitchAuthorizer = vm.envAddress("KILL_SWITCH_AUTHORIZER");

        initialOwner = vm.addr(vm.envUint("PRIVATE_KEY"));
        salt = vm.envOr("CREATE2_SALT", uint256(0));

        if (verifier == address(0)) {
            verifier = deployVerifier(initialOwner, salt);
        }

        // Deploy Useroverridable DKIM registry
        dkim = UserOverrideableDKIMRegistry(vm.envOr("DKIM_REGISTRY", address(0)));
        uint256 setTimeDelay = vm.envOr("DKIM_DELAY", uint256(0));
        if (address(dkim) == address(0)) {
            dkim = UserOverrideableDKIMRegistry(
                deployUserOverrideableDKIMRegistry(
                    initialOwner, dkimRegistrySigner, setTimeDelay, salt
                )
            );
        }

        if (emailAuthImpl == address(0)) {
            emailAuthImpl = address(new EmailAuth{ salt: bytes32(salt) }());
            console.log("Deployed Email Auth at", emailAuthImpl);
        }

        if (validatorAddr == address(0)) {
            validatorAddr = address(new OwnableValidator{ salt: bytes32(salt) }());
            console.log("Deployed Ownable Validator at", validatorAddr);
        }

        address _factory = vm.envOr("RECOVERY_FACTORY", address(0));
        if (_factory == address(0)) {
            _factory =
                address(new EmailRecoveryFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl, eoaVerifier, eoaAuthImpl));
                //address(new EmailRecoveryFactory{ salt: bytes32(salt) }(verifier, emailAuthImpl));
            console.log("Deployed Email Recovery Factory at", _factory);
        }
        {
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

            console.log("Deployed Email Recovery Module at", vm.toString(module));
            console.log("Deployed Email Recovery Handler at", vm.toString(commandHandler));
            vm.stopBroadcast();
        }
    }
}
