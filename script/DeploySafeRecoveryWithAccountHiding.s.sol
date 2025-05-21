// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from
    "script/base/BaseDeployUniversalEmailRecovery.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract DeploySafeRecoveryWithAccountHidingScript is BaseDeployUniversalEmailRecoveryScript {
    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(AccountHidingRecoveryCommandHandler).creationCode;
    }

    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
