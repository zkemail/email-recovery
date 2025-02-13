// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployEmailRecoveryScript } from "./base/BaseDeployEmailRecovery.s.sol";

contract DeployEmailRecoveryScript is BaseDeployEmailRecoveryScript {
    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deploy();
        vm.stopBroadcast();
    }
}
