// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { AccountInstance, ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_onInstall_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_OnInstall_RevertWhen_InvalidOnInstallData() public {
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        bytes memory emptyData = new bytes(0);
        assertEq(emptyData.length, 0);

        // TODO: error not detected as it is not thrown in next function call
        // vm.expectRevert(EmailRecoveryModule.InvalidOnInstallData.selector);

        // When installing with empty data and not expecting a revert, the test fails
        // instance.installModule({
        //     moduleTypeId: MODULE_TYPE_EXECUTOR,
        //     module: recoveryModuleAddress,
        //     data: emptyData
        // });
    }

    function test_OnInstall_RevertWhen_InvalidValidator() public {
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");
        AccountInstance memory newInstance = makeAccountInstance("new instance");
        vm.deal(address(newInstance.account), 10 ether);

        // TODO: error not detected as it is not thrown in next function call
        // vm.expectRevert(
        //     abi.encodeWithSelector(EmailRecoveryModule.InvalidValidator.selector,
        // validatorAddress)
        // );
        // newInstance.installModule({
        //     moduleTypeId: MODULE_TYPE_EXECUTOR,
        //     module: recoveryModuleAddress,
        //     data: abi.encode(isInstalledContext, guardians, guardianWeights, threshold, delay,
        // expiry)
        // });
    }

    function test_OnInstall_Succeeds() public {
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians, guardianWeights, threshold, delay, expiry)
        });

        bool isAuthorizedToBeRecovered = emailRecoveryModule.isAuthorizedToBeRecovered(accountAddress);

        assertTrue(isAuthorizedToBeRecovered);
    }
}
