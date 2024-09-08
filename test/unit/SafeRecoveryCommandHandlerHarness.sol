// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract SafeRecoveryCommandHandlerHarness is SafeRecoveryCommandHandler {
    constructor() SafeRecoveryCommandHandler() { }

    function exposed_getPreviousOwnerInLinkedList(
        address safe,
        address oldOwner
    )
        external
        view
        returns (address)
    {
        return getPreviousOwnerInLinkedList(safe, oldOwner);
    }
}
