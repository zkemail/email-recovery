// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeploySafeNativeRecoveryWithAccountHidingScript } from
    "../DeploySafeNativeRecoveryWithAccountHiding.s.sol";

contract DeploySafeNativeRecoveryWithAccountHidingTest is BaseDeployTest {
    DeploySafeNativeRecoveryWithAccountHidingScript private target;

    function setUp() public override {
        super.setUp();
        target = new DeploySafeNativeRecoveryWithAccountHidingScript();
    }

    function test_RevertIf_NoPrivateKeyEnv() public {
        super.setAllEnvVars();

        vm.setEnv("PRIVATE_KEY", "");
        vm.expectRevert(
            "vm.envUint: failed parsing $PRIVATE_KEY as type `uint256`: missing hex prefix (\"0x\") for hex string"
        );
        target.run();
    }

    function test_RevertIf_NoKillSwitchAuthorizerEnv() public {
        super.setAllEnvVars();

        vm.setEnv("KILL_SWITCH_AUTHORIZER", "");
        vm.expectRevert(
            "vm.envAddress: failed parsing $KILL_SWITCH_AUTHORIZER as type `address`: parser error:\n$KILL_SWITCH_AUTHORIZER\n^\nexpected hex digits or the `0x` prefix for an empty hex string"
        );
        target.run();
    }

    function test_RevertIf_NoDkimRegistryAndSignerEnvs() public {
        super.setAllEnvVars();

        vm.setEnv("DKIM_REGISTRY", "");
        vm.setEnv("DKIM_SIGNER", "");

        vm.expectRevert("DKIM_REGISTRY or DKIM_SIGNER is required");
        target.run();
    }

    function test_NoVerifierEnv() public {
        super.setAllEnvVars();

        vm.setEnv("VERIFIER", "");

        target.run();

        require(target.zkVerifier() != address(0), "verifier not deployed");
    }

    function test_NoDkimRegistryEnv() public {
        super.setAllEnvVars();

        vm.setEnv("DKIM_REGISTRY", "");

        target.run();

        require(address(target.dkimRegistry()) != address(0), "dkim not deployed");
    }

    function test_NoEmailAuthImplEnv() public {
        super.setAllEnvVars();

        vm.setEnv("EMAIL_AUTH_IMPL", "");

        target.run();

        require(target.emailAuthImpl() != address(0), "email auth not deployed");
    }

    function test_NoCommandHandlerEnv() public {
        super.setAllEnvVars();

        vm.setEnv("COMMAND_HANDLER", "");

        target.run();

        require(target.commandHandler() != address(0), "command handler not deployed");
    }

    function test_Deployment() public {
        super.setAllEnvVars();

        target.run();

        require(target.module() != address(0), "module not deployed");
    }
}
