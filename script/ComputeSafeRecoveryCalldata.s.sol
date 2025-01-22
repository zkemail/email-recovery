// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

contract ComputeSafeRecoveryCalldataScript is Script {
    address private oldOwner;
    address private newOwner;

    bytes public recoveryCalldata;

    function loadEnvVars() public {
        // revert if these are not set
        oldOwner = vm.envAddress("OLD_OWNER");
        newOwner = vm.envAddress("NEW_OWNER");
    }

    function run() public {
        loadEnvVars();

        address previousOwnerInLinkedList = address(1);
        recoveryCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", previousOwnerInLinkedList, oldOwner, newOwner
        );

        console.log("recoveryCalldata", vm.toString(recoveryCalldata));
    }
}
