// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from
    "./base/BaseDeployUniversalEmailRecovery.s.sol";

// 1. `source .env`
// 2. `forge script --chain sepolia script/DeploySafeRecovery.s.sol:DeploySafeRecoveryScript
// --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv`
contract DeploySafeRecoveryScript is BaseDeployUniversalEmailRecoveryScript {
    function run() public override {
        super.run();

        commandHandlerType = CommandHandlerType.SafeRecovery;

        vm.startBroadcast(config.privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
