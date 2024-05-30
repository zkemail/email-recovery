// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { SafeZkEmailRecovery } from "src/SafeZkEmailRecovery.sol";
import { SafeRecoveryModule } from "src/modules/SafeRecoveryModule.sol";

contract DeploySafeRecoveryScript is Script {
    function run() public {
        bytes32 salt = bytes32(uint256(0));

        address verifier = 0xEdC642bbaD91E21cCE6cd436Fdc6F040FD0fF998;
        address ecdsaOwnedDkimRegistry = 0xC83256CCf7B94d310e49edA05077899ca036eb78;
        address emailAuthImpl = 0x1C76Aa365c17B40c7E944DcCdE4dC6e6D2A7b748;

        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        SafeZkEmailRecovery safeZkEmailRecovery =
            new SafeZkEmailRecovery{ salt: salt }(verifier, ecdsaOwnedDkimRegistry, emailAuthImpl);
        new SafeRecoveryModule(address(safeZkEmailRecovery));

        vm.stopBroadcast();
    }
}
