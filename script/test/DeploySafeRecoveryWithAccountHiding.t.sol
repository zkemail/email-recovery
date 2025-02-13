// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { BaseDeployUniversalEmailRecoveryTest } from "./base/BaseDeployUniversalEmailRecovery.t.sol";
import { DeploySafeRecoveryWithAccountHidingScript } from
    "../DeploySafeRecoveryWithAccountHiding.s.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract DeploySafeRecoveryWithAccountHidingTest is BaseDeployUniversalEmailRecoveryTest {
    function setUp() public override {
        super.setUp();
        target = new DeploySafeRecoveryWithAccountHidingScript();
    }

    function getCommandHandlerBytecode() internal pure override returns (bytes memory) {
        return type(AccountHidingRecoveryCommandHandler).creationCode;
    }
}
