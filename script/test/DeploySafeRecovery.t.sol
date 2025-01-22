// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Vm } from "forge-std/Vm.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeploySafeRecoveryScript } from "../DeploySafeRecovery.s.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract DeploySafeRecoveryTest is BaseDeployTest {
    DeploySafeRecoveryScript private target;

    function setUp() public override {
        super.setUp();
        target = new DeploySafeRecoveryScript();
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

        vm.setEnv("VERIFIER", vm.toString(address(0)));

        target.run();

        require(target.verifier() != address(0), "verifier not deployed");
    }

    function test_NoDkimRegistryEnv() public {
        setAllEnvVars();

        vm.setEnv("DKIM_REGISTRY", vm.toString(address(0)));

        target.run();

        require(address(target.dkimRegistry()) != address(0), "dkim registry not deployed");
    }

    function test_NoEmailAuthImplEnv() public {
        setAllEnvVars();

        vm.setEnv("EMAIL_AUTH_IMPL", vm.toString(address(0)));

        target.run();

        require(target.emailAuthImpl() != address(0), "email auth implementation not deployed");
    }

    function test_DeploymentEvent() public {
        setAllEnvVars();

        vm.recordLogs();
        target.run();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 sigHash = keccak256("UniversalEmailRecoveryModuleDeployed(address,address)");
        assertTrue(findEvent(entries, sigHash), "deploy event not emitted");
    }

    function test_Deployment() public {
        setAllEnvVars();

        address expectedRecoveryFactory = computeAddress(
            envCreate2Salt,
            type(EmailRecoveryUniversalFactory).creationCode,
            abi.encode(envVerifier, envEmailAuthImpl)
        );

        uint256 commandHandlerSalt = envCreate2Salt;
        address expectedCommandHandler = computeAddress(
            commandHandlerSalt,
            type(SafeRecoveryCommandHandler).creationCode,
            "",
            expectedRecoveryFactory
        );

        uint256 recoveryModuleSalt = envCreate2Salt;
        address expectedRecoveryModule = computeAddress(
            recoveryModuleSalt,
            type(UniversalEmailRecoveryModule).creationCode,
            abi.encode(
                envVerifier,
                envDkimRegistry,
                envEmailAuthImpl,
                expectedCommandHandler,
                envMinimumDelay,
                envKillSwitchAuthorizer
            ),
            expectedRecoveryFactory
        );

        target.run();

        require(
            target.emailRecoveryHandler() == expectedCommandHandler,
            "email recovery handler not deployed to expected address"
        );
        require(
            target.emailRecoveryModule() == expectedRecoveryModule,
            "email recovery module not deployed to expected address"
        );
    }
}
