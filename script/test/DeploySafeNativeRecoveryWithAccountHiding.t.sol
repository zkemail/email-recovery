// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeRecoveryTest } from
    "script/test/base/BaseDeploySafeNativeRecovery.t.sol";
import { DeploySafeNativeRecoveryWithAccountHidingScript } from
    "script/DeploySafeNativeRecoveryWithAccountHiding.s.sol";
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

    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(AccountHidingRecoveryCommandHandler).creationCode;
    }
}
