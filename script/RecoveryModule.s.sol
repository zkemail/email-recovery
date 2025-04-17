// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {RecoveryModule} from "../src/RecoveryModule.sol";

contract CounterScript is Script {
    RecoveryModule public recoveryModule;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        recoveryModule = new RecoveryModule();

        vm.stopBroadcast();
    }
}
