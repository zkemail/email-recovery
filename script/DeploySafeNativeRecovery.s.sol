// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeRecoveryScript } from "./base/BaseDeploySafeNativeRecovery.s.sol";

contract DeploySafeNativeRecoveryScript is BaseDeploySafeNativeRecoveryScript {
    address public module;

    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deploySafeNativeRecovery(CommandHandlerType.SafeRecovery);
        vm.stopBroadcast();
    }
}
