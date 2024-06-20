// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";

contract SafeRecoverySubjectHandlerHarness is SafeRecoverySubjectHandler {
    constructor() SafeRecoverySubjectHandler() { }

    function exposed_getPreviousOwnerInLinkedList(
        address safe,
        address oldOwner
    )
        external
        returns (address)
    {
        return getPreviousOwnerInLinkedList(safe, oldOwner);
    }
}
