// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeploySafeNativeRecoveryWithAccountHidingScript } from
    "../DeploySafeNativeRecoveryWithAccountHiding.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

contract DeploySafeNativeRecoveryWithAccountHidingTest is BaseDeployTest {
    DeploySafeNativeRecoveryWithAccountHidingScript private target;
    address private envZkVerifier;
    address private envCommandHandler;

    function setUp() public override {
        super.setUp();
        envZkVerifier = super.deployVerifier(envInitialOwner);
        envCommandHandler = deployAccountHidingRecoveryCommandHandler(envCreate2Salt);

        target = new DeploySafeNativeRecoveryWithAccountHidingScript();
    }

    function setAllEnvVars() internal override {
        super.setAllEnvVars();

        vm.setEnv("ZK_VERIFIER", vm.toString(envZkVerifier));
        vm.setEnv("COMMAND_HANDLER", vm.toString(envCommandHandler));
    }

    function deployAccountHidingRecoveryCommandHandler(uint256 salt) internal returns (address) {
        return address(new AccountHidingRecoveryCommandHandler{ salt: bytes32(salt) }());
    }

    function test_RevertIf_NoPrivateKeyEnv() public {
        setAllEnvVars();

        vm.setEnv("PRIVATE_KEY", "");
        vm.expectRevert(
            "vm.envUint: failed parsing $PRIVATE_KEY as type `uint256`: missing hex prefix (\"0x\") for hex string"
        );
        target.run();
    }

    function test_RevertIf_NoKillSwitchAuthorizerEnv() public {
        setAllEnvVars();

        vm.setEnv("KILL_SWITCH_AUTHORIZER", "");
        vm.expectRevert(
            "vm.envAddress: failed parsing $KILL_SWITCH_AUTHORIZER as type `address`: parser error:\n$KILL_SWITCH_AUTHORIZER\n^\nexpected hex digits or the `0x` prefix for an empty hex string"
        );
        target.run();
    }

    function test_RevertIf_NoDkimRegistryAndSignerEnvs() public {
        setAllEnvVars();

        vm.setEnv("DKIM_REGISTRY", "");
        vm.setEnv("DKIM_SIGNER", "");

        vm.expectRevert("DKIM_REGISTRY or DKIM_SIGNER is required");
        target.run();
    }

    function test_NoVerifierEnv() public {
        setAllEnvVars();

        vm.setEnv("VERIFIER", "");

        target.run();

        require(target.zkVerifier() != address(0), "verifier not deployed");
    }

    function test_NoDkimRegistryEnv() public {
        setAllEnvVars();

        vm.setEnv("DKIM_REGISTRY", "");

        target.run();

        require(address(target.dkimRegistry()) != address(0), "dkim not deployed");
    }

    function test_NoEmailAuthImplEnv() public {
        setAllEnvVars();

        vm.setEnv("EMAIL_AUTH_IMPL", "");

        target.run();

        require(target.emailAuthImpl() != address(0), "email auth not deployed");
    }

    function test_NoCommandHandlerEnv() public {
        setAllEnvVars();

        vm.setEnv("COMMAND_HANDLER", "");

        target.run();

        require(target.commandHandler() != address(0), "command handler not deployed");
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedModuleAddress = computeAddress(
            envCreate2Salt,
            type(SafeEmailRecoveryModule).creationCode,
            abi.encode(
                envZkVerifier,
                envDkimRegistry,
                envEmailAuthImpl,
                envCommandHandler,
                envMinimumDelay,
                envKillSwitchAuthorizer
            )
        );

        target.run();

        require(target.module() == expectedModuleAddress, "module not deployed to expected address");
    }
}
