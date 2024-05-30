// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {ModuleKitHelpers, ModuleKitUserOp} from "modulekit/ModuleKit.sol";
import {MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR} from "modulekit/external/ERC7579.sol";

import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";
import {OwnableValidator} from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_deInitRecoveryFromModule_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
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
            data: abi.encode(
                address(validator),
                guardians,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });
    }

    function test_DeInitRecoveryFromModule_RevertWhen_NotCalledFromRecoveryModule()
        public
    {
        vm.expectRevert(IZkEmailRecovery.NotRecoveryModule.selector);
        zkEmailRecovery.deInitRecoveryFromModule(accountAddress);
    }

    function test_DeInitRecoveryFromModule_RevertWhen_RecoveryInProcess()
        public
    {
        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.prank(recoveryModuleAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.deInitRecoveryFromModule(accountAddress);
    }

    function test_DeInitRecoveryFromModule_Succeeds() public {
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        acceptGuardian(accountSalt1);
        acceptGuardian(accountSalt2);

        vm.prank(recoveryModuleAddress);
        vm.expectEmit();
        emit IZkEmailRecovery.RecoveryDeInitialized(accountAddress);
        zkEmailRecovery.deInitRecoveryFromModule(accountAddress);

        // assert that recovery config has been cleared successfully
        IZkEmailRecovery.RecoveryConfig memory recoveryConfig = zkEmailRecovery
            .getRecoveryConfig(accountAddress);
        assertEq(recoveryConfig.recoveryModule, address(0));
        assertEq(recoveryConfig.delay, 0);
        assertEq(recoveryConfig.expiry, 0);

        // assert that the recovery request has been cleared successfully
        IZkEmailRecovery.RecoveryRequest
            memory recoveryRequest = zkEmailRecovery.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);
        assertEq(recoveryRequest.subjectParams.length, 0);

        // assert that guardian storage has been cleared successfully for guardian 1
        GuardianStorage memory guardianStorage1 = zkEmailRecovery.getGuardian(
            accountAddress,
            guardian1
        );
        assertEq(
            uint256(guardianStorage1.status),
            uint256(GuardianStatus.NONE)
        );
        assertEq(guardianStorage1.weight, uint256(0));

        // assert that guardian storage has been cleared successfully for guardian 2
        GuardianStorage memory guardianStorage2 = zkEmailRecovery.getGuardian(
            accountAddress,
            guardian2
        );
        assertEq(
            uint256(guardianStorage2.status),
            uint256(GuardianStatus.NONE)
        );
        assertEq(guardianStorage2.weight, uint256(0));

        // assert that guardian config has been cleared successfully
        IZkEmailRecovery.GuardianConfig memory guardianConfig = zkEmailRecovery
            .getGuardianConfig(accountAddress);
        assertEq(guardianConfig.guardianCount, 0);
        assertEq(guardianConfig.totalWeight, 0);
        assertEq(guardianConfig.threshold, 0);

        // assert that the recovery router mappings have been cleared successfully
        address accountForRouter = zkEmailRecovery.getAccountForRouter(router);
        address routerForAccount = zkEmailRecovery.getRouterForAccount(
            accountAddress
        );
        assertEq(accountForRouter, address(0));
        assertEq(routerForAccount, address(0));
    }
}
