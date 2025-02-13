// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryTest } from "./base/BaseDeployUniversalEmailRecovery.t.sol";
import { DeployUniversalEmailRecoveryScript } from "../DeployUniversalEmailRecovery.s.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

contract DeployUniversalEmailRecoveryModuleTest is BaseDeployUniversalEmailRecoveryTest {
    function setUp() public override {
        super.setUp();
        target = new DeployUniversalEmailRecoveryScript();
    }

    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(EmailRecoveryCommandHandler).creationCode;
    }
}
