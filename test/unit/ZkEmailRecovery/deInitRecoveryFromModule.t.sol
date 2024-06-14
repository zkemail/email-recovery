// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_deInitRecoveryFromModule_Test is UnitBase {
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

    // function test_DeInitRecoveryFromModule_RevertWhen_NotCalledFromRecoveryModule() public {
    //     vm.expectRevert(IEmailRecoveryManager.NotRecoveryModule.selector);
    //     emailRecoveryManager.deInitRecoveryFromModule(accountAddress);
    // }

    // function test_DeInitRecoveryFromModule_RevertWhen_RecoveryInProcess() public {
    //     acceptGuardian(accountSalt1);
    //     vm.warp(12 seconds);
    //     handleRecovery(recoveryModuleAddress, accountSalt1);

    //     vm.prank(recoveryModuleAddress);
    //     vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
    //     emailRecoveryManager.deInitRecoveryFromModule(accountAddress);
    // }

    // function test_DeInitRecoveryFromModule_Succeeds() public {
    //     acceptGuardian(accountSalt1);
    //     acceptGuardian(accountSalt2);

    //     vm.prank(recoveryModuleAddress);
    //     vm.expectEmit();
    //     emit IEmailRecoveryManager.RecoveryDeInitialized(accountAddress);
    //     emailRecoveryManager.deInitRecoveryFromModule(accountAddress);

    //     // assert that recovery config has been cleared successfully
    //     IEmailRecoveryManager.RecoveryConfig memory recoveryConfig =
    //         emailRecoveryManager.getRecoveryConfig(accountAddress);
    //     assertEq(recoveryConfig.delay, 0);
    //     assertEq(recoveryConfig.expiry, 0);

    //     // assert that the recovery request has been cleared successfully
    //     IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
    //         emailRecoveryManager.getRecoveryRequest(accountAddress);
    //     assertEq(recoveryRequest.executeAfter, 0);
    //     assertEq(recoveryRequest.executeBefore, 0);
    //     assertEq(recoveryRequest.currentWeight, 0);

    //     // assert that guardian storage has been cleared successfully for guardian 1
    //     GuardianStorage memory guardianStorage1 =
    //         emailRecoveryManager.getGuardian(accountAddress, guardian1);
    //     assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.NONE));
    //     assertEq(guardianStorage1.weight, uint256(0));

    //     // assert that guardian storage has been cleared successfully for guardian 2
    //     GuardianStorage memory guardianStorage2 =
    //         emailRecoveryManager.getGuardian(accountAddress, guardian2);
    //     assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.NONE));
    //     assertEq(guardianStorage2.weight, uint256(0));

    //     // assert that guardian config has been cleared successfully
    //     IEmailRecoveryManager.GuardianConfig memory guardianConfig =
    //         emailRecoveryManager.getGuardianConfig(accountAddress);
    //     assertEq(guardianConfig.guardianCount, 0);
    //     assertEq(guardianConfig.totalWeight, 0);
    //     assertEq(guardianConfig.threshold, 0);
    // }
}
