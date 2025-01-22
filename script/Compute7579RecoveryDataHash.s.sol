// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

/* solhint-disable no-console */

import { console } from "forge-std/console.sol";
import { Script } from "forge-std/Script.sol";

contract Compute7579RecoveryDataHashScript is Script {
    address private newOwner;
    address private validator;

    bytes public recoveryData;
    bytes32 public recoveryDataHash;

    function loadEnvVars() public {
        // revert if these are not set
        newOwner = vm.envAddress("NEW_OWNER");
        validator = vm.envAddress("VALIDATOR");
    }

    function run() public {
        loadEnvVars();

        bytes4 functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        bytes memory changeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        recoveryData = abi.encode(validator, changeOwnerCalldata);
        recoveryDataHash = keccak256(recoveryData);

        console.log("recoveryData", vm.toString(recoveryData));
        console.log("recoveryDataHash", vm.toString(recoveryDataHash));
    }
}
