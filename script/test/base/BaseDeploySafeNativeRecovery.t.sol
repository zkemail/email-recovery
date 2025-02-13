// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployTest } from "./BaseDeploy.t.sol";
import { BaseDeploySafeNativeRecoveryScript } from "../../base/BaseDeploySafeNativeRecovery.s.sol";
import { Groth16Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Groth16Verifier.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract BaseDeploySafeNativeRecoveryTest is BaseDeployTest {
    function commonTest_NoZkVerifierEnv(BaseDeploySafeNativeRecoveryScript target) public {
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
}
