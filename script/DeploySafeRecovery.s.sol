// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from
    "script/base/BaseDeployUniversalEmailRecovery.s.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

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
