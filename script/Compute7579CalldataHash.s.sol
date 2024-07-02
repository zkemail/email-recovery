// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract Compute7579CalldataHash is Script {
    function run() public {
        bytes4 functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        address newOwner = vm.envAddress("NEW_OWNER");

        bytes memory recoveryCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes32 calldataHash = keccak256(recoveryCalldata);

        console.log("recoveryCalldata", vm.toString(recoveryCalldata));
        console.log("calldataHash", vm.toString(calldataHash));
    }
}
