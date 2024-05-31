// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { IEmailAccountRecovery } from "src/interfaces/IEmailAccountRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

import { OwnableValidatorBase } from "./OwnableValidatorBase.t.sol";

contract OwnableValidatorRecovery_Integration_Test is OwnableValidatorBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, recoveryModuleAddress)
        });
        // Install recovery module - configureRecovery is called on `onInstall`
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(address(validator), guardians, guardianWeights, threshold, delay, expiry)
        });
    }

    function test_Recover_RotatesOwnerSuccessfully() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

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
        assertEq(recoveryRequest.subjectParams.length, 0);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);
        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);
        assertEq(recoveryRequest.subjectParams.length, 3);
        assertEq(recoveryRequest.subjectParams[0], abi.encode(accountAddress));
        assertEq(recoveryRequest.subjectParams[1], abi.encode(newOwner));
        assertEq(recoveryRequest.subjectParams[2], abi.encode(recoveryModuleAddress));

        // Time travel so that the recovery delay has passed
        vm.warp(block.timestamp + delay);

        // Complete recovery
        IEmailAccountRecovery(router).completeRecovery();

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        address updatedOwner = validator.owners(accountAddress);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
        assertEq(updatedOwner, newOwner);
    }

    function test_Recover_TryInstallModuleAfterFailedConfigureRecovery() public {
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        // This call fails because the account forgot to install the module before starting the
        // recovery flow
        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryModuleNotInstalled.selector);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(address(validator), guardians, guardianWeights, threshold, delay, expiry)
        });

        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);
        vm.warp(12 seconds);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt1);
        handleRecovery(newOwner, recoveryModuleAddress, accountSalt2);

        vm.warp(block.timestamp + delay);

        IEmailAccountRecovery(router).completeRecovery();

        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        address updatedOwner = validator.owners(accountAddress);

        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);
        assertEq(updatedOwner, newOwner);
    }

    function test_OnUninstall_DeInitsStateSuccessfully() public {
        // configure and complete an entire recovery request
        test_Recover_RotatesOwnerSuccessfully();
        address router = zkEmailRecovery.computeRouterAddress(keccak256(abi.encode(accountAddress)));

        // Uninstall module
        vm.prank(accountAddress);
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        vm.stopPrank();

        bool isModuleInstalled =
            instance.isModuleInstalled(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        assertFalse(isModuleInstalled);

        // assert that recovery config has been cleared successfully
        IZkEmailRecovery.RecoveryConfig memory recoveryConfig =
            zkEmailRecovery.getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.recoveryModule, address(0));
        assertEq(recoveryConfig.delay, 0);
        assertEq(recoveryConfig.expiry, 0);

        // assert that the recovery request has been cleared successfully
        IZkEmailRecovery.RecoveryRequest memory recoveryRequest =
            zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);

        // assert that guardian storage has been cleared successfully for guardian 1
        GuardianStorage memory guardianStorage1 =
            zkEmailRecovery.getGuardian(accountAddress, guardian1);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage1.weight, uint256(0));

        // assert that guardian storage has been cleared successfully for guardian 2
        GuardianStorage memory guardianStorage2 =
            zkEmailRecovery.getGuardian(accountAddress, guardian2);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
        assertEq(guardianStorage2.weight, uint256(0));

        // assert that guardian config has been cleared successfully
        IZkEmailRecovery.GuardianConfig memory guardianConfig =
            zkEmailRecovery.getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, 0);
        assertEq(guardianConfig.totalWeight, 0);
        assertEq(guardianConfig.threshold, 0);

        // assert that the recovery router mappings have been cleared successfully
        address accountForRouter = zkEmailRecovery.getAccountForRouter(router);
        address routerForAccount = zkEmailRecovery.getRouterForAccount(accountAddress);
        assertEq(accountForRouter, address(0));
        assertEq(routerForAccount, address(0));
    }
}
