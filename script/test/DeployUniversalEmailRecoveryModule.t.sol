// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Vm } from "forge-std/Vm.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeployUniversalEmailRecoveryModuleScript } from
    "../DeployUniversalEmailRecoveryModule.s.sol";

contract DeployUniversalEmailRecoveryModuleTest is BaseDeployTest {
    DeployUniversalEmailRecoveryModuleScript private target;

    function setUp() public override {
        super.setUp();
        target = new DeployUniversalEmailRecoveryModuleScript();
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

        require(target.verifier() != address(0), "verifier not deployed");
    }

    function test_NoDkimRegistryEnv() public {
        super.setAllEnvVars();

        vm.setEnv("DKIM_REGISTRY", "");

        target.run();

        require(address(target.dkimRegistry()) != address(0), "dkim registry not deployed");
    }

    function test_NoEmailAuthImplEnv() public {
        super.setAllEnvVars();

        vm.setEnv("EMAIL_AUTH_IMPL", "");

        target.run();

        require(target.emailAuthImpl() != address(0), "email auth implementation not deployed");
    }

    function test_NoRecoveryFactoryEnv() public {
        super.setAllEnvVars();

        vm.setEnv("RECOVERY_FACTORY", "");

        target.run();

        require(target.recoveryFactory() != address(0), "recovery factory not deployed");
    }

    function test_Deployment() public {
        super.setAllEnvVars();

        vm.recordLogs();
        target.run();

        require(target.emailRecoveryModule() != address(0), "email recovery module not deployed");
        require(target.emailRecoveryHandler() != address(0), "email recovery handler not deployed");
    }

    function test_DeploymentEvent() public {
        super.setAllEnvVars();

        vm.recordLogs();
        target.run();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 sigHash = keccak256("UniversalEmailRecoveryModuleDeployed(address,address)");
        assertTrue(super.findEvent(entries, sigHash), "deploy event not emitted");
    }
}
