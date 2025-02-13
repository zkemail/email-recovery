// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeRecoveryScript } from "./base/BaseDeploySafeNativeRecovery.s.sol";

contract DeploySafeNativeRecoveryWithAccountHidingScript is BaseDeploySafeNativeRecoveryScript {
    address public module;

    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deploySafeNativeRecovery(CommandHandlerType.AccountHidingRecovery);
        vm.stopBroadcast();
    }
}
