// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeRecoveryTest } from "./base/BaseDeploySafeNativeRecovery.t.sol";
import { DeploySafeNativeRecoveryWithAccountHidingScript } from
    "../DeploySafeNativeRecoveryWithAccountHiding.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract DeploySafeNativeRecoveryWithAccountHidingTest is BaseDeploySafeNativeRecoveryTest {
    function setUp() public override {
        super.setUp();

        target = new DeploySafeNativeRecoveryWithAccountHidingScript();
    }

    function deployCommandHandler() internal override {
        config.commandHandler =
            address(new AccountHidingRecoveryCommandHandler{ salt: config.create2Salt }());
    }

    function test_NoCommandHandlerEnv() public {
        setAllEnvVars();
        vm.setEnv("COMMAND_HANDLER", "");

        address handler = computeAddress(
            config.create2Salt, type(AccountHidingRecoveryCommandHandler).creationCode, ""
        );

        assert(!isContractDeployed(handler));
        target.run();
        assert(isContractDeployed(handler));
    }
}
