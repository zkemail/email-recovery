// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeploySafeNativeScript } from "./BaseDeploySafeNative.s.sol";

contract DeploySafeNativeRecoveryScript is BaseDeploySafeNativeScript {
    address public module;

    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deploySafeNativeRecovery(CommandHandlerType.SafeRecovery);
        vm.stopBroadcast();
    }
}
