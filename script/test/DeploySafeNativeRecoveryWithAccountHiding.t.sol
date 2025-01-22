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
        commonTest_RevertIf_NoPrivateKeyEnv(target);
    }

    function test_RevertIf_NoKillSwitchAuthorizerEnv() public {
        setAllEnvVars();
        commonTest_RevertIf_NoKillSwitchAuthorizerEnv(target);
    }

    function test_RevertIf_NoDkimRegistryAndSignerEnvs() public {
        setAllEnvVars();
        commonTest_RevertIf_NoDkimRegistryAndSignerEnvs(target);
    }

    function test_NoZkVerifierEnv() public {
        setAllEnvVars();
        commonTest_NoZkVerifierEnv(target);
    }

    function test_NoDkimRegistryEnv() public {
        setAllEnvVars();
        commonTest_NoDkimRegistryEnv(target);
    }

    function test_NoEmailAuthImplEnv() public {
        setAllEnvVars();
        commonTest_NoEmailAuthImplEnv(target);
    }

    function test_NoCommandHandlerEnv() public {
        setAllEnvVars();
        vm.setEnv("COMMAND_HANDLER", "");

        address handler = computeAddress(
            envCreate2Salt, type(AccountHidingRecoveryCommandHandler).creationCode, ""
        );

        require(!isContractDeployed(handler), "handler should not be deployed yet");
        target.run();
        require(isContractDeployed(handler), "handler should be deployed");
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

        require(!isContractDeployed(expectedModuleAddress), "module should not be deployed yet");
        target.run();
        require(isContractDeployed(expectedModuleAddress), "module should be deployed");
        // also checking returned address
        require(target.module() == expectedModuleAddress, "module address mismatch");
    }
}
