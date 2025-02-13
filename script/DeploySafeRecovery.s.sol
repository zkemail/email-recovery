// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from
    "script/base/BaseDeployUniversalEmailRecovery.s.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

// 1. `source .env`
// 2. `forge script --chain sepolia script/DeploySafeRecovery.s.sol:DeploySafeRecoveryScript
// --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast -vvvv`
contract DeploySafeRecoveryScript is BaseDeployUniversalEmailRecoveryScript {
    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(SafeRecoveryCommandHandler).creationCode;
    }

    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
