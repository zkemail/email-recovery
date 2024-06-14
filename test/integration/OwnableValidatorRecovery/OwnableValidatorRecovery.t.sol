// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorRecoveryBase } from "./OwnableValidatorRecoveryBase.t.sol";

contract OwnableValidatorRecovery_Integration_Test is OwnableValidatorRecoveryBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;

    bytes4 functionSelector;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();

        functionSelector = bytes4(keccak256(bytes("changeOwner(address,address,address)")));

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, recoveryModuleAddress)
        });
        // Install recovery module - configureRecovery is called on `onInstall`
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(
                address(validator),
                functionSelector,
                guardians,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });
    }

    function test_Recover_RotatesOwnerSuccessfully() public {
        bytes memory recoveryCalldata = abi.encodeWithSignature(
            "changeOwner(address,address,address)", accountAddress, recoveryModuleAddress, newOwner
        );
        bytes32 calldataHash = keccak256(recoveryCalldata);

        // Accept guardian 1
        acceptGuardian(accountSalt1);
        GuardianStorage memory guardianStorage1 =
            emailRecoveryManager.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian 2
        acceptGuardian(accountSalt2);
        GuardianStorage memory guardianStorage2 =
            emailRecoveryManager.getGuardian(accountAddress, guardian2);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);
        // handle recovery request for guardian 1
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt1);
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            emailRecoveryManager.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecovery(recoveryModuleAddress, calldataHash, accountSalt2);
        recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + delay);

        // Complete recovery
        emailRecoveryManager.completeRecovery(accountAddress, recoveryCalldata);

        recoveryRequest = emailRecoveryManager.getRecoveryRequest(accountAddress);
        address updatedOwner = validator.owners(accountAddress);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(updatedOwner, newOwner);
    }
}
