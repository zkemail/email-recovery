// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract Compute7579RecoveryDataHash is Script {
    function run() public view {
        bytes4 functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        address newOwner = vm.envAddress("NEW_OWNER");
        address validator = vm.envAddress("VALIDATOR");

        bytes memory changeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes memory recoveryData = abi.encode(validator, changeOwnerCalldata);
        bytes32 recoveryDataHash = keccak256(recoveryData);

        console.log("recoveryData", vm.toString(recoveryData));
        console.log("recoveryDataHash", vm.toString(recoveryDataHash));
    }
}
