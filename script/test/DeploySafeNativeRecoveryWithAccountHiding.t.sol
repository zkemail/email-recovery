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
        config.commandHandler = deployAccountHidingRecoveryCommandHandler(config.create2Salt);

        target = new DeploySafeNativeRecoveryWithAccountHidingScript();
    }

    function deployAccountHidingRecoveryCommandHandler(bytes32 salt) internal returns (address) {
        return address(new AccountHidingRecoveryCommandHandler{ salt: bytes32(salt) }());
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
