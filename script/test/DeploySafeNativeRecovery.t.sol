// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeRecoveryTest } from "./base/BaseDeploySafeNativeRecovery.t.sol";
import { DeploySafeNativeRecoveryScript } from "../DeploySafeNativeRecovery.s.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract DeploySafeNativeRecoveryTest is BaseDeploySafeNativeRecoveryTest {
    function setUp() public override {
        super.setUp();
        config.commandHandler = deploySafeRecoveryCommandHandler(config.create2Salt);

        target = new DeploySafeNativeRecoveryScript();
    }

    function deploySafeRecoveryCommandHandler(bytes32 salt) internal returns (address) {
        return address(new SafeRecoveryCommandHandler{ salt: bytes32(salt) }());
    }

    function test_NoCommandHandlerEnv() public {
        setAllEnvVars();
        vm.setEnv("COMMAND_HANDLER", "");

        address handler =
            computeAddress(config.create2Salt, type(SafeRecoveryCommandHandler).creationCode, "");

        assert(!isContractDeployed(handler));
        target.run();
        assert(isContractDeployed(handler));
    }
}
