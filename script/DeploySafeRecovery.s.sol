// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalScript } from "./BaseDeployUniversal.s.sol";

// 1. `source .env`
// 2. `forge script --chain sepolia script/DeploySafeRecovery.s.sol:DeploySafeRecovery_Script
// --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv`
contract DeploySafeRecoveryScript is BaseDeployUniversalScript {
    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deployUniversalEmailRecovery(CommandHandlerType.SafeRecovery);
        vm.stopBroadcast();
    }
}
