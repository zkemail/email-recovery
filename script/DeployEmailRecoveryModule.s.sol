// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployEmailRecoveryModuleScript } from "./BaseDeployEmailRecoveryModule.s.sol";

contract DeployEmailRecoveryModuleScript is BaseDeployEmailRecoveryModuleScript {
    function run() public override {
        super.run();

        vm.startBroadcast(config.privateKey);
        deployEmailRecoveryModule();
        vm.stopBroadcast();
    }
}
