// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console2 } from "forge-std/console2.sol";
import { BaseTest } from "./Base.t.sol";
import { Vm } from "forge-std/Vm.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { BaseDeployScript } from "../../base/BaseDeploy.s.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { UserOverrideableDKIMRegistry } from "@zk-email/contracts/UserOverrideableDKIMRegistry.sol";

abstract contract BaseDeployTest is BaseTest {
    BaseDeployScript internal target;

    function setUp() public virtual override {
        super.setUp();
    }

    // ### TEST CASES ###

    function test_RevertIf_NoPrivateKeyEnv() public {
        setAllEnvVars();
        vm.setEnv("PRIVATE_KEY", "");
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeployScript.MissingRequiredParameter.selector, "PRIVATE_KEY"
            )
        );
        target.run();
    }

    function test_RevertIf_NoKillSwitchAuthorizerEnv() public {
        setAllEnvVars();
        vm.setEnv("KILL_SWITCH_AUTHORIZER", "");
        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeployScript.MissingRequiredParameter.selector, "KILL_SWITCH_AUTHORIZER"
            )
        );
        target.run();
    }

    function test_RevertIf_NoDkimRegistryAndSignerEnvs() public {
        setAllEnvVars();
        vm.setEnv("DKIM_REGISTRY", "");
        vm.setEnv("DKIM_SIGNER", "");

        vm.expectRevert(
            abi.encodeWithSelector(
                BaseDeployScript.MissingRequiredParameter.selector, "DKIM_REGISTRY/DKIM_SIGNER"
            )
        );
        target.run();
    }

    function test_NoDkimRegistryEnv() public {
        setAllEnvVars();
        vm.setEnv("DKIM_REGISTRY", "");

        address initialOwner = vm.addr(config.privateKey);

        address dkim =
            computeAddress(config.create2Salt, type(UserOverrideableDKIMRegistry).creationCode, "");
        address proxy = computeAddress(
            config.create2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                dkim,
                abi.encodeCall(
                    UserOverrideableDKIMRegistry(dkim).initialize,
                    (initialOwner, config.dkimSigner, config.dkimDelay)
                )
            )
        );

        assert(!isContractDeployed(proxy));
        target.run();
        assert(isContractDeployed(proxy));
    }

    function test_NoEmailAuthImplEnv() public {
        setAllEnvVars();
        vm.setEnv("EMAIL_AUTH_IMPL", "");

        address emailAuthImpl = computeAddress(config.create2Salt, type(EmailAuth).creationCode, "");

        assert(!isContractDeployed(emailAuthImpl));
        target.run();
        assert(isContractDeployed(emailAuthImpl));
    }

    // ### COMMON TEST FUNCTIONS ###

    function commonTest_DeploymentEvent(bytes memory eventSignature) internal {
        setAllEnvVars();
        vm.recordLogs();
        target.run();

        Vm.Log[] memory entries = vm.getRecordedLogs();
        assertTrue(findEvent(entries, keccak256(eventSignature)), "deploy event not emitted");
    }

    function commonTest_NoVerifierEnv() internal {
        setAllEnvVars();
        vm.setEnv("VERIFIER", "");

        address initialOwner = vm.addr(config.privateKey);

        address verifier = computeAddress(config.create2Salt, type(Verifier).creationCode, "");
        address groth16 = computeAddress(config.create2Salt, type(Groth16Verifier).creationCode, "");
        address proxy = computeAddress(
            config.create2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                verifier,
                abi.encodeCall(Verifier(verifier).initialize, (initialOwner, address(groth16)))
            )
        );

        assert(!isContractDeployed(proxy));
        target.run();
        assert(isContractDeployed(proxy));
    }
}
