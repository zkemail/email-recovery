// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { SafeNativeIntegrationBase } from
    "../../../integration/SafeRecovery/SafeNativeIntegrationBase.t.sol";

contract SafeEmailRecoveryModule_configureSafeRecovery_Test is SafeNativeIntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ConfigureSafeRecovery_RevertWhen_ModuleNotInstalled() public {
        skipIfNotSafeAccountType();

        vm.startPrank(safeAddress);
        safe.disableModule(address(1), address(emailRecoveryModule));
        vm.expectRevert(
            abi.encodeWithSelector(SafeEmailRecoveryModule.ModuleNotInstalled.selector, safeAddress)
        );
        emailRecoveryModule.configureSafeRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
    }
}
