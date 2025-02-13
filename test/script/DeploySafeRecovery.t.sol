// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryTest } from
    "test/script/base/BaseDeployUniversalEmailRecovery.t.sol";
import { DeploySafeRecoveryScript } from "script/DeploySafeRecovery.s.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract DeploySafeRecoveryTest is BaseDeployUniversalEmailRecoveryTest {
    function setUp() public override {
        super.setUp();
        target = new DeploySafeRecoveryScript();
    }

    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(SafeRecoveryCommandHandler).creationCode;
    }
}
