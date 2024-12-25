// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

contract Compute7579RecoveryDataHash is Script {
    bytes4 functionSelector;
    address public newOwner;
    address validator;
    bytes32 public recoveryDataHash;
    function run() public  {
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
         newOwner = vm.envAddress("NEW_OWNER");
         validator = vm.envAddress("VALIDATOR");

        bytes memory changeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes memory recoveryData = abi.encode(validator, changeOwnerCalldata);
        recoveryDataHash = keccak256(recoveryData);

        console.log("recoveryData", vm.toString(recoveryData));
        console.log("recoveryDataHash", vm.toString(recoveryDataHash));
    }
}
