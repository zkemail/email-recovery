// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

/* solhint-disable no-console */

import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { StdUtils } from "forge-std/StdUtils.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { Verifier } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { EmailAuth } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { EmailRecoveryCommandHandler } from "../../src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryUniversalFactory } from "../../src/factories/EmailRecoveryUniversalFactory.sol";

abstract contract BaseDeployTest is Test {
    bytes32 salt;
    
    function setUp() public virtual {
        salt = bytes32(vm.envOr("CREATE2_SALT", uint256(0)));
        
        // Set environment variables
        vm.setEnv("PRIVATE_KEY", vm.toString(uint256(1)));
    }

    function computeCreate2Address(
        bytes32 _salt,
        bytes32 _bytecodeHash,
        address _deployer
    ) internal pure override returns (address) {
        return Create2.computeAddress(_salt, _bytecodeHash, _deployer);
    }
}
