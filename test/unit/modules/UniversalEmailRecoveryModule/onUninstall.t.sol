// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { SentinelListHelper } from "sentinellist/SentinelListHelper.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_onUninstall_Test is UnitBase {
    using ModuleKitHelpers for *;
    using SentinelListHelper for address[];

    function setUp() public override {
        super.setUp();
    }

    function test_OnUninstall_Succeeds() public {
        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.stopPrank();

        bytes4 allowedSelector =
            emailRecoveryModule.exposed_allowedSelectors(validatorAddress, accountAddress1);
        assertEq(allowedSelector, bytes4(0));

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress1);
        assertEq(allowedValidators.length, 0);
        assertEq(allowedSelectors.length, 0);
    }

    function test_OnUninstall_SucceedsWhenNoValidatorsConfigured() public {
        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);
        address prevValidator = allowedValidators.findPrevious(validatorAddress);

        vm.startPrank(accountAddress1);
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, prevValidator, functionSelector
        );
        vm.stopPrank();

        allowedValidators = emailRecoveryModule.getAllowedValidators(accountAddress1);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress1);
        assertEq(allowedValidators.length, 0);
        assertEq(allowedSelectors.length, 0);

        vm.prank(accountAddress1);
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");
        vm.stopPrank();

        allowedValidators = emailRecoveryModule.getAllowedValidators(accountAddress1);
        allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress1);
        assertEq(allowedValidators.length, 0);
        assertEq(allowedSelectors.length, 0);

        bool isActivated = emailRecoveryModule.isActivated(accountAddress1);
        assertFalse(isActivated);
    }
}
