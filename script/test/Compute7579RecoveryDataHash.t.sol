// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { Test } from "forge-std/Test.sol";
import { VmSafe } from "forge-std/Vm.sol";
import { Compute7579RecoveryDataHash } from "../Compute7579RecoveryDataHash.s.sol";
import { BaseDeployTest } from "./BaseDeployTest.sol";

contract Compute7579RecoveryDataHashTest is BaseDeployTest {
    Compute7579RecoveryDataHash hasher;
    bytes4 constant CHANGE_OWNER_SELECTOR = bytes4(keccak256(bytes("changeOwner(address)")));

    function setUp() public override {
        super.setUp();
        hasher = new Compute7579RecoveryDataHash();
        
        // Set required environment variables if not set in BaseDeployTest
        if (vm.envAddress("NEW_OWNER") == address(0)) {
            vm.setEnv("NEW_OWNER", vm.toString(makeAddr("newOwner")));
        }
        if (vm.envAddress("VALIDATOR") == address(0)) {
            vm.setEnv("VALIDATOR", vm.toString(makeAddr("validator")));
        }
    }

    function test_ComputeRecoveryDataHash() public {
        // Calculate expected values
        address newOwner = vm.envAddress("NEW_OWNER");
        address validator = vm.envAddress("VALIDATOR");
        
        bytes memory expectedCalldata = abi.encodeWithSelector(CHANGE_OWNER_SELECTOR, newOwner);
        bytes memory expectedRecoveryData = abi.encode(validator, expectedCalldata);
        bytes32 expectedHash = keccak256(expectedRecoveryData);
        
        // Store log length before execution
        uint256 preLogsLength = vm.getRecordedLogs().length;
        
        // Run script
        hasher.run();
        
        // Get and verify logs
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        assertEq(logs.length - preLogsLength, 2, "Incorrect number of logs emitted");
        
        string memory recoveryDataLog = abi.decode(logs[preLogsLength].data, (string));
        string memory recoveryHashLog = abi.decode(logs[preLogsLength + 1].data, (string));
        
        assertEq(recoveryDataLog, vm.toString(expectedRecoveryData), "Recovery data mismatch");
        assertEq(recoveryHashLog, vm.toString(expectedHash), "Recovery hash mismatch");
    }

    function test_ComputeWithDifferentOwner() public {
        address differentOwner = makeAddr("differentOwner");
        vm.setEnv("NEW_OWNER", vm.toString(differentOwner));
        
        bytes memory expectedCalldata = abi.encodeWithSelector(CHANGE_OWNER_SELECTOR, differentOwner);
        bytes memory expectedRecoveryData = abi.encode(vm.envAddress("VALIDATOR"), expectedCalldata);
        bytes32 expectedHash = keccak256(expectedRecoveryData);
        
        hasher.run();
        
        VmSafe.Log[] memory logs = vm.getRecordedLogs();
        string memory recoveryHashLog = abi.decode(logs[logs.length - 1].data, (string));
        assertEq(recoveryHashLog, vm.toString(expectedHash), "Hash mismatch with different owner");
    }

    function testFail_ComputeWithZeroAddressOwner() public {
        vm.setEnv("NEW_OWNER", vm.toString(address(0)));
        hasher.run();
    }

    function testFail_ComputeWithZeroAddressValidator() public {
        vm.setEnv("VALIDATOR", vm.toString(address(0)));
        hasher.run();
    }
}
