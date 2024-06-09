// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { IEmailAccountRecovery } from "src/interfaces/IEmailAccountRecovery.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { ValidatorEmailRecoveryModule } from "src/modules/ValidatorEmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { ValidatorEmailRecoveryModuleBase } from "./ValidatorEmailRecoveryModuleBase.t.sol";

contract ValidatorEmailRecoveryModule_Integration_Test is ValidatorEmailRecoveryModuleBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    ValidatorEmailRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    bytes4 functionSelector;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule =
            new ValidatorEmailRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);

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
                expiry,
                acceptanceSubjectTemplates(),
                recoverySubjectTemplates()
            )
        });
    }

    function test_Recover_RotatesOwnerSuccessfully() public {
        bytes memory recoveryCalldata = abi.encodeWithSignature(
            "changeOwner(address,address,address)", accountAddress, recoveryModuleAddress, newOwner
        );

        // Accept guardian 1
        acceptGuardian(accountSalt1);
        GuardianStorage memory guardianStorage1 =
            zkEmailRecovery.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian 2
        acceptGuardian(accountSalt2);
        GuardianStorage memory guardianStorage2 =
            zkEmailRecovery.getGuardian(accountAddress, guardian2);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);
        // handle recovery request for guardian 1
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);
        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + delay);

        // Complete recovery
        zkEmailRecovery.completeRecovery(accountAddress);

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        address updatedOwner = validator.owners(accountAddress);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(updatedOwner, newOwner);
    }
}
