// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console } from "forge-std/console.sol";
import { BaseDeploySafeNativeRecoveryTest } from "./base/BaseDeploySafeNativeRecovery.t.sol";
import { DeploySafeNativeRecoveryScript } from "../DeploySafeNativeRecovery.s.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract DeploySafeNativeRecoveryTest is BaseDeploySafeNativeRecoveryTest {
    function setUp() public override {
        super.setUp();
        target = new DeploySafeNativeRecoveryScript();
    }

    function deployCommandHandler() internal override {
        config.commandHandler =
            address(new SafeRecoveryCommandHandler{ salt: config.create2Salt }());
        console.log("Deployed Command Handler at", config.commandHandler);
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
