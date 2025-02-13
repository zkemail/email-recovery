// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from
    "./base/BaseDeployUniversalEmailRecovery.s.sol";

contract DeployUniversalEmailRecoveryScript is BaseDeployUniversalEmailRecoveryScript {
    function run() public override {
        super.run();

        commandHandlerType = CommandHandlerType.EmailRecovery;

        vm.startBroadcast(config.privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
