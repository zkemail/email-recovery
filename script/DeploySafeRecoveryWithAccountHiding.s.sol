// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from "./BaseDeployUniversalEmailRecovery.s.sol";

// 1. `source .env`
// 2. `forge script
// script/DeploySafeRecoveryWithAccountHiding.s.sol:DeploySafeRecoveryWithAccountHiding_Script
// --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`
contract DeploySafeRecoveryWithAccountHidingScript is BaseDeployUniversalEmailRecoveryScript {
    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deployUniversalEmailRecovery(CommandHandlerType.AccountHidingRecovery);
        vm.stopBroadcast();
    }
}
