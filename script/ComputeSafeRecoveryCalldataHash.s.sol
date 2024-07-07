// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { ISafe } from "src/interfaces/ISafe.sol";

contract ComputeSafeRecoveryCalldataHashScript is Script {
    function run() public {
        address safe = vm.envAddress("SAFE_ACCOUNT");

        bytes4 functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));
        address oldOwner = vm.envAddress("OLD_OWNER");
        address newOwner = vm.envAddress("NEW_OWNER");
        address previousOwnerInLinkedList = getPreviousOwnerInLinkedList(safe, oldOwner);

        bytes memory recoveryCalldata = abi.encodeWithSelector(
            functionSelector, previousOwnerInLinkedList, oldOwner, newOwner
        );
        bytes32 calldataHash = keccak256(recoveryCalldata);

        console.log("recoveryCalldata", vm.toString(recoveryCalldata));
        console.log("calldataHash", vm.toString(calldataHash));
    }

    function getPreviousOwnerInLinkedList(
        address safe,
        address oldOwner
    )
        internal
        view
        returns (address)
    {
        address[] memory owners = ISafe(safe).getOwners();
        uint256 length = owners.length;

        uint256 oldOwnerIndex;
        for (uint256 i; i < length; i++) {
            if (owners[i] == oldOwner) {
                oldOwnerIndex = i;
                break;
            }
        }
        address sentinelOwner = address(0x1);
        return oldOwnerIndex == 0 ? sentinelOwner : owners[oldOwnerIndex - 1];
    }
}
