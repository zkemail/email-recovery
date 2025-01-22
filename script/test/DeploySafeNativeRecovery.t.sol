// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { BaseDeployTest } from "./BaseDeployTest.sol";
import { DeploySafeNativeRecoveryScript } from "../DeploySafeNativeRecovery.s.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";

contract DeploySafeNativeRecoveryTest is BaseDeployTest {
    DeploySafeNativeRecoveryScript private target;
    address private envZkVerifier;
    address private envCommandHandler;

    function setUp() public override {
        super.setUp();
        envZkVerifier = super.deployVerifier(envInitialOwner);
        envCommandHandler = deploySafeRecoveryCommandHandler(envCreate2Salt);

        target = new DeploySafeNativeRecoveryScript();
    }

    function setAllEnvVars() internal override {
        super.setAllEnvVars();

        vm.setEnv("ZK_VERIFIER", vm.toString(envZkVerifier));
        vm.setEnv("COMMAND_HANDLER", vm.toString(envCommandHandler));
    }

    function deploySafeRecoveryCommandHandler(uint256 salt) internal returns (address) {
        return address(new SafeRecoveryCommandHandler{ salt: bytes32(salt) }());
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

        address handler =
            computeAddress(envCreate2Salt, type(SafeRecoveryCommandHandler).creationCode, "");

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
