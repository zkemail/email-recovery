// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";

contract ZkEmailRecovery_cancelRecovery_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_CancelRecovery_CannotCancelWrongRecoveryRequest() public {
        address otherAddress = address(99);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        IZkEmailRecovery.RecoveryRequest
            memory recoveryRequest = zkEmailRecovery.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.subjectParams.length, 0);

        vm.startPrank(otherAddress);
        zkEmailRecovery.cancelRecovery("");

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }

    function test_CancelRecovery_PartialRequest_Succeeds() public {
        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        IZkEmailRecovery.RecoveryRequest
            memory recoveryRequest = zkEmailRecovery.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);
        assertEq(recoveryRequest.subjectParams.length, 0);

        vm.startPrank(accountAddress);
        zkEmailRecovery.cancelRecovery("");

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }

    function test_CancelRecovery_FullRequest_Succeeds() public {
        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);
        handleRecovery(recoveryModuleAddress, accountSalt2);

        IZkEmailRecovery.RecoveryRequest
            memory recoveryRequest = zkEmailRecovery.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.executeAfter, block.timestamp + delay);
        assertEq(recoveryRequest.executeBefore, block.timestamp + expiry);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.subjectParams.length, 3);
        assertEq(recoveryRequest.subjectParams[0], abi.encode(accountAddress));
        assertEq(recoveryRequest.subjectParams[1], abi.encode(newOwner));
        assertEq(
            recoveryRequest.subjectParams[2],
            abi.encode(recoveryModuleAddress)
        );

        vm.startPrank(accountAddress);
        zkEmailRecovery.cancelRecovery("");

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
    }
}
