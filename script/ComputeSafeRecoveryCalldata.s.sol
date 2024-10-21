// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract ComputeSafeRecoveryCalldataScript is Script {
    function run() public view {
        address oldOwner = vm.envAddress("OLD_OWNER");
        address newOwner = vm.envAddress("NEW_OWNER");
        address previousOwnerInLinkedList = address(1);

        bytes memory recoveryCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", previousOwnerInLinkedList, oldOwner, newOwner
        );

        console.log("recoveryCalldata", vm.toString(recoveryCalldata));
    }
}
