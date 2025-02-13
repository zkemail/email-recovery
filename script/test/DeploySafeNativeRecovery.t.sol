// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console } from "forge-std/console.sol";
import { BaseDeploySafeNativeRecoveryTest } from
    "script/test/base/BaseDeploySafeNativeRecovery.t.sol";
import { DeploySafeNativeRecoveryScript } from "script/DeploySafeNativeRecovery.s.sol";
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

    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(SafeRecoveryCommandHandler).creationCode;
    }
}
