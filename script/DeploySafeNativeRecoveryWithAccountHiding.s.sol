// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console } from "forge-std/console.sol";
import { BaseDeploySafeNativeRecoveryScript } from "./base/BaseDeploySafeNativeRecovery.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract DeploySafeNativeRecoveryWithAccountHidingScript is BaseDeploySafeNativeRecoveryScript {
    address public module;

    function deployCommandHandlerIfNotDeployed() internal {
        if (config.commandHandler == address(0)) {
            config.commandHandler =
                address(new AccountHidingRecoveryCommandHandler{ salt: config.create2Salt }());
            console.log("Deployed Command Handler at", config.commandHandler);
        }
    }

    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deployCommandHandlerIfNotDeployed();
        deploy();
        vm.stopBroadcast();
    }
}
