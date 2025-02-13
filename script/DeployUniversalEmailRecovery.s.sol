// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryScript } from "./BaseDeployUniversalEmailRecovery.s.sol";

contract DeployUniversalEmailRecoveryScript is BaseDeployUniversalEmailRecoveryScript {
    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deployUniversalEmailRecovery(CommandHandlerType.EmailRecovery);
        vm.stopBroadcast();
    }
}
