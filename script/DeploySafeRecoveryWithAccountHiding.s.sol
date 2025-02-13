// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from
    "./base/BaseDeployUniversalEmailRecovery.s.sol";

// 1. `source .env`
// 2. `forge script
// script/DeploySafeRecoveryWithAccountHiding.s.sol:DeploySafeRecoveryWithAccountHidingScript
// --rpc-url $RPC_URL --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY -vvvv`
contract DeploySafeRecoveryWithAccountHidingScript is BaseDeployUniversalEmailRecoveryScript {
    function run() public override {
        super.run();

        commandHandlerType = CommandHandlerType.AccountHidingRecovery;

        vm.startBroadcast(config.privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
