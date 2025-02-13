// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from
    "script/base/BaseDeployUniversalEmailRecovery.s.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

contract DeployUniversalEmailRecoveryScript is BaseDeployUniversalEmailRecoveryScript {
    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(EmailRecoveryCommandHandler).creationCode;
    }

    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
