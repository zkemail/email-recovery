// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { BaseDeployTest } from "./BaseDeploy.t.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";

abstract contract BaseDeploySafeNativeRecoveryTest is BaseDeployTest {
    function setUp() public virtual override {
        super.setUp();
        deployCommandHandler();
    }

    function deployCommandHandler() internal virtual;

    function test_NoZkVerifierEnv() public {
        setAllEnvVars();
        vm.setEnv("ZK_VERIFIER", "");

        address initialOwner = vm.addr(config.privateKey);

        address zkVerifier = computeAddress(config.create2Salt, type(Verifier).creationCode, "");
        address groth16 = computeAddress(config.create2Salt, type(Groth16Verifier).creationCode, "");
        address proxy = computeAddress(
            config.create2Salt,
            type(ERC1967Proxy).creationCode,
            abi.encode(
                zkVerifier,
                abi.encodeCall(Verifier(zkVerifier).initialize, (initialOwner, address(groth16)))
            )
        );

        assert(!isContractDeployed(proxy));
        target.run();
        assert(isContractDeployed(proxy));
    }

    function test_NoDkimRegistryEnv() public {
        commonTest_NoDkimRegistryEnv();
    }

    function test_NoEmailAuthImplEnv() public {
        commonTest_NoEmailAuthImplEnv();
    }

    function test_Deployment() public {
        setAllEnvVars();

        console2.log("s", uint256(config.create2Salt));

        console2.log("test_Deployment zkVerifier %s", config.zkVerifier);
        console2.log("test_Deployment dkimRegistry %s", config.dkimRegistry);
        console2.log("test_Deployment emailAuthImpl %s", config.emailAuthImpl);
        console2.log("test_Deployment commandHandler %s", config.commandHandler);
        console2.log("test_Deployment minimumDelay %s", config.minimumDelay);
        console2.log("test_Deployment killSwitchAuthorizer %s", config.killSwitchAuthorizer);

        address expectedModuleAddress = computeAddress(
            config.create2Salt,
            type(SafeEmailRecoveryModule).creationCode,
            abi.encode(
                config.zkVerifier,
                config.dkimRegistry,
                config.emailAuthImpl,
                config.commandHandler,
                config.minimumDelay,
                config.killSwitchAuthorizer
            )
        );

        assert(!isContractDeployed(expectedModuleAddress));
        target.run();
        assert(isContractDeployed(expectedModuleAddress));
        // also checking returned address
        assertEq(target.emailRecoveryModule(), expectedModuleAddress);
    }
}
