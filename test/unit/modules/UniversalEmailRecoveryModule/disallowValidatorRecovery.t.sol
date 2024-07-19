// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR, MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { SentinelListHelper } from "sentinellist/SentinelListHelper.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_disallowValidatorRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;

    using SentinelListHelper for address[];

    function setUp() public override {
        super.setUp();
    }

    function test_DisallowValidatorRecovery_RevertWhen_RecoveryModuleNotInitialized() public {
        // Uninstall module so module is not initialized
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        vm.startPrank(accountAddress);
        vm.expectRevert(UniversalEmailRecoveryModule.RecoveryModuleNotInitialized.selector);
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, address(1), bytes("0"), functionSelector
        );
    }

    function test_DisallowValidatorRecovery_RevertWhen_InvalidPreviousValidator() public {
        OwnableValidator newValidator = new OwnableValidator();
        address invalidPreviousValidator = address(newValidator);

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                SentinelListLib.LinkedList_InvalidEntry.selector, validatorAddress
            )
        );
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, invalidPreviousValidator, "", functionSelector
        );
    }

    function test_DisallowValidatorRecovery_RevertsWhen_ValidatorNotAllowed() public {
        // Deplopy and install new validator
        OwnableValidator newValidator = new OwnableValidator();
        address newValidatorAddress = address(newValidator);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidatorAddress,
            data: abi.encode(owner)
        });

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress);
        address prevValidator = allowedValidators.findPrevious(validatorAddress);

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                SentinelListLib.LinkedList_InvalidEntry.selector, newValidatorAddress
            )
        );
        emailRecoveryModule.disallowValidatorRecovery(
            newValidatorAddress, prevValidator, "", functionSelector
        );
    }

    function test_DisallowValidatorRecovery_RevertsWhen_InvalidSelector() public {
        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress);
        address prevValidator = allowedValidators.findPrevious(validatorAddress);

        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));

        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, invalidSelector
            )
        );
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, prevValidator, "", invalidSelector
        );

        allowedValidators = emailRecoveryModule.getAllowedValidators(accountAddress);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress);
        assertEq(allowedValidators.length, 1);
        assertEq(allowedSelectors.length, 1);
    }

    function test_DisallowValidatorRecovery_Succeeds() public {
        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress);
        address prevValidator = allowedValidators.findPrevious(validatorAddress);

        vm.startPrank(accountAddress);
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, prevValidator, "", functionSelector
        );

        allowedValidators = emailRecoveryModule.getAllowedValidators(accountAddress);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress);
        assertEq(allowedValidators.length, 0);
        assertEq(allowedSelectors.length, 0);
    }

    function test_DisallowValidatorRecovery_SucceedsWhenValidatorUninstalled() public {
        instance.uninstallModule(MODULE_TYPE_VALIDATOR, validatorAddress, "");

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress);
        address prevValidator = allowedValidators.findPrevious(validatorAddress);

        vm.startPrank(accountAddress);
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, prevValidator, bytes("0"), functionSelector
        );

        allowedValidators = emailRecoveryModule.getAllowedValidators(accountAddress);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress);
        assertEq(allowedValidators.length, 0);
        assertEq(allowedSelectors.length, 0);
    }

    function test_DisallowValidatorRecovery_DisallowsCorrectValidatorOutOfMultiple() public {
        // Deplopy and install new validator
        OwnableValidator newValidator = new OwnableValidator();
        address newValidatorAddress = address(newValidator);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidatorAddress,
            data: abi.encode(owner)
        });

        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(newValidatorAddress, "", functionSelector);

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress);
        address prevValidator = allowedValidators.findPrevious(validatorAddress);

        vm.startPrank(accountAddress);
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, prevValidator, "", functionSelector
        );

        allowedValidators = emailRecoveryModule.getAllowedValidators(accountAddress);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress);
        assertEq(allowedValidators.length, 1);
        assertEq(allowedValidators[0], newValidatorAddress);
        assertEq(allowedSelectors.length, 1);
        assertEq(allowedSelectors[0], functionSelector);
    }
}
