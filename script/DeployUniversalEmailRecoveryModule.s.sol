// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalScript } from "./BaseDeployUniversal.s.sol";

contract DeployUniversalEmailRecoveryModuleScript is BaseDeployUniversalScript {
    function run() public override {
        super.run();

        vm.startBroadcast(privateKey);
        deployUniversalEmailRecovery(CommandHandlerType.EmailRecovery);
        vm.stopBroadcast();
    }
}
