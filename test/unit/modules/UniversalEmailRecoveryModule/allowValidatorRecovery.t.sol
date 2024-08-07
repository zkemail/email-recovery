// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { ISafe } from "src/interfaces/ISafe.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_allowValidatorRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;

    function setUp() public override {
        super.setUp();
    }

    function test_AllowValidatorRecovery_RevertWhen_RecoveryModuleNotInitialized() public {
        // Uninstall module so module is not initialized
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        vm.startPrank(accountAddress);
        vm.expectRevert(UniversalEmailRecoveryModule.RecoveryModuleNotInitialized.selector);
        emailRecoveryModule.allowValidatorRecovery(validatorAddress, bytes("0"), functionSelector);
    }

    function test_AllowValidatorRecovery_RevertWhen_UnsafeOnInstallSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, IModule.onInstall.selector
            )
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(
            validatorAddress, bytes("0"), IModule.onInstall.selector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_UnsafeOnUninstallSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, IModule.onUninstall.selector
            )
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(
            validatorAddress, bytes("0"), IModule.onUninstall.selector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_UnsafeExecuteSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector,
                IERC7579Account.execute.selector
            )
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(
            validatorAddress, bytes("0"), IERC7579Account.execute.selector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_UnsafeSetFallbackHandlerSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector,
                ISafe.setFallbackHandler.selector
            )
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(
            validatorAddress, bytes("0"), ISafe.setFallbackHandler.selector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_UnsafeSetGuardSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, ISafe.setGuard.selector
            )
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(
            validatorAddress, bytes("0"), ISafe.setGuard.selector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_InvalidSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(UniversalEmailRecoveryModule.InvalidSelector.selector, bytes4(0))
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(validatorAddress, bytes("0"), bytes4(0));
    }

    function test_AllowValidatorRecovery_RevertWhen_InvalidValidator() public {
        OwnableValidator newValidator = new OwnableValidator();
        address newValidatorAddress = address(newValidator);

        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidValidator.selector, newValidatorAddress
            )
        );
        vm.startPrank(accountAddress);
        emailRecoveryModule.allowValidatorRecovery(
            newValidatorAddress, bytes("0"), functionSelector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_ValidatorAlreadyInList() public {
        vm.startPrank(accountAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                SentinelListLib.LinkedList_EntryAlreadyInList.selector, validatorAddress
            )
        );
        emailRecoveryModule.allowValidatorRecovery(validatorAddress, "", functionSelector);
    }

    function test_AllowValidatorRecovery_RevertWhen_MaxValidatorsReached() public {
        // One validator is already installed from setup
        for (uint256 i = 1; i <= 31; i++) {
            address newValidatorAddress = address(new OwnableValidator());
            instance.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: newValidatorAddress,
                data: abi.encode(owner)
            });
            vm.startPrank(accountAddress);
            emailRecoveryModule.allowValidatorRecovery(newValidatorAddress, "", functionSelector);
            vm.stopPrank();
        }

        address newValidatorAddress = address(new OwnableValidator());
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidatorAddress,
            data: abi.encode(owner)
        });
        vm.startPrank(accountAddress);
        vm.expectRevert(UniversalEmailRecoveryModule.MaxValidatorsReached.selector);
        emailRecoveryModule.allowValidatorRecovery(newValidatorAddress, "", functionSelector);

        uint256 validatorCount = emailRecoveryModule.validatorCount(accountAddress);
        assertEq(validatorCount, 32);
    }

    function test_AllowValidatorRecovery_SucceedsWhenAlreadyInitialized() public {
        // Deplopy and install new validator
        OwnableValidator newValidator = new OwnableValidator();
        address newValidatorAddress = address(newValidator);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidatorAddress,
            data: abi.encode(owner)
        });

        vm.startPrank(accountAddress);
        vm.expectEmit();
        emit UniversalEmailRecoveryModule.NewValidatorRecovery({
            account: accountAddress,
            validator: newValidatorAddress,
            recoverySelector: functionSelector
        });
        emailRecoveryModule.allowValidatorRecovery(newValidatorAddress, "", functionSelector);

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress);

        assertEq(allowedValidators.length, 2);
        assertEq(allowedValidators[0], newValidatorAddress);
        assertEq(allowedValidators[1], validatorAddress);
        assertEq(allowedSelectors.length, 2);
        assertEq(allowedSelectors[0], functionSelector);
        assertEq(allowedSelectors[1], functionSelector);
    }

    function test_AllowValidatorRecovery_SucceedsWhenInitializing() public {
        // Uninstall module so state is reset
        instance.uninstallModule(MODULE_TYPE_EXECUTOR, recoveryModuleAddress, "");

        instance.installModule(
            MODULE_TYPE_EXECUTOR,
            recoveryModuleAddress,
            abi.encode(
                validatorAddress,
                isInstalledContext,
                functionSelector,
                guardians,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        );

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress);

        assertEq(allowedValidators.length, 1);
        assertEq(allowedValidators[0], validatorAddress);
        assertEq(allowedSelectors.length, 1);
        assertEq(allowedSelectors[0], functionSelector);
    }
}
