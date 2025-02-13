// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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

    function getCommandHandlerBytecode() internal pure virtual returns (bytes memory);

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

    function test_NoCommandHandlerEnv() public {
        setAllEnvVars();
        vm.setEnv("COMMAND_HANDLER", "");

        address handler = computeAddress(config.create2Salt, getCommandHandlerBytecode(), "");

        assert(!isContractDeployed(handler));
        target.run();
        assert(isContractDeployed(handler));
    }

    function test_Deployment() public {
        setAllEnvVars();

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
