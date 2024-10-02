// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { IModule } from "erc7579/interfaces/IERC7579Module.sol";
import { ISafe } from "src/interfaces/ISafe.sol";
import { SentinelListLib } from "sentinellist/SentinelList.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract UniversalEmailRecoveryModule_allowValidatorRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;

    address public newValidatorAddress;

    function setUp() public override {
        super.setUp();
        // Deploy & install new validator to avoid `LinkedList_EntryAlreadyInList` errors
        OwnableValidator newValidator = new OwnableValidator();
        newValidatorAddress = address(newValidator);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidatorAddress,
            data: abi.encode(owner1)
        });
    }

    function test_AllowValidatorRecovery_RevertWhen_RecoveryModuleNotInitialized() public {
        // Uninstall module so module is not initialized
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.startPrank(accountAddress1);
        vm.expectRevert(UniversalEmailRecoveryModule.RecoveryModuleNotInitialized.selector);
        emailRecoveryModule.allowValidatorRecovery(validatorAddress, bytes("0"), functionSelector);
    }

    function test_AllowValidatorRecovery_When_SafeAddOwnerSelector() public {
        _skipIfNotSafeAccountType();
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(
            newValidatorAddress, bytes("0"), ISafe.addOwnerWithThreshold.selector
        );
    }

    function test_AllowValidatorRecovery_When_SafeRemoveOwnerSelector() public {
        _skipIfNotSafeAccountType();
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(
            newValidatorAddress, bytes("0"), ISafe.removeOwner.selector
        );
    }

    function test_AllowValidatorRecovery_When_SafeSwapOwnerSelector() public {
        _skipIfNotSafeAccountType();
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(
            newValidatorAddress, bytes("0"), ISafe.swapOwner.selector
        );
    }

    function test_AllowValidatorRecovery_When_SafeChangeThresholdSelector() public {
        _skipIfNotSafeAccountType();
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(
            newValidatorAddress, bytes("0"), ISafe.changeThreshold.selector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_UnsafeOnInstallSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, IModule.onInstall.selector
            )
        );
        vm.startPrank(accountAddress1);
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
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(
            validatorAddress, bytes("0"), IModule.onUninstall.selector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_InvalidSelector() public {
        vm.expectRevert(
            abi.encodeWithSelector(UniversalEmailRecoveryModule.InvalidSelector.selector, bytes4(0))
        );
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(validatorAddress, bytes("0"), bytes4(0));
    }

    function test_AllowValidatorRecovery_RevertWhen_InvalidValidator() public {
        instance1.uninstallModule(MODULE_TYPE_VALIDATOR, newValidatorAddress, "");
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidValidator.selector, newValidatorAddress
            )
        );
        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(
            newValidatorAddress, bytes("0"), functionSelector
        );
    }

    function test_AllowValidatorRecovery_RevertWhen_ValidatorAlreadyInList() public {
        vm.startPrank(accountAddress1);
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
            address _newValidatorAddress = address(new OwnableValidator());
            instance1.installModule({
                moduleTypeId: MODULE_TYPE_VALIDATOR,
                module: _newValidatorAddress,
                data: abi.encode(owner1)
            });
            vm.startPrank(accountAddress1);
            emailRecoveryModule.allowValidatorRecovery(_newValidatorAddress, "", functionSelector);
            vm.stopPrank();
        }

        address lastValidatorAddress = address(new OwnableValidator());
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: lastValidatorAddress,
            data: abi.encode(owner1)
        });
        vm.startPrank(accountAddress1);
        vm.expectRevert(UniversalEmailRecoveryModule.MaxValidatorsReached.selector);
        emailRecoveryModule.allowValidatorRecovery(lastValidatorAddress, "", functionSelector);

        uint256 validatorCount = emailRecoveryModule.validatorCount(accountAddress1);
        assertEq(validatorCount, 32);
    }

    function test_AllowValidatorRecovery_SucceedsWhenAlreadyInitialized() public {
        vm.startPrank(accountAddress1);
        vm.expectEmit();
        emit UniversalEmailRecoveryModule.NewValidatorRecovery({
            account: accountAddress1,
            validator: newValidatorAddress,
            recoverySelector: functionSelector
        });
        emailRecoveryModule.allowValidatorRecovery(newValidatorAddress, "", functionSelector);

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress1);

        assertEq(allowedValidators.length, 2);
        assertEq(allowedValidators[0], newValidatorAddress);
        assertEq(allowedValidators[1], validatorAddress);
        assertEq(allowedSelectors.length, 2);
        assertEq(allowedSelectors[0], functionSelector);
        assertEq(allowedSelectors[1], functionSelector);
    }

    function test_AllowValidatorRecovery_SucceedsWhenInitializing() public {
        // Uninstall module so state is reset
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        instance1.installModule(
            MODULE_TYPE_EXECUTOR,
            emailRecoveryModuleAddress,
            abi.encode(
                validatorAddress,
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        );

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);
        bytes4[] memory allowedSelectors = emailRecoveryModule.getAllowedSelectors(accountAddress1);

        assertEq(allowedValidators.length, 1);
        assertEq(allowedValidators[0], validatorAddress);
        assertEq(allowedSelectors.length, 1);
        assertEq(allowedSelectors[0], functionSelector);
    }

    function _skipIfNotSafeAccountType() private {
        string memory currentAccountType = vm.envOr("ACCOUNT_TYPE", string(""));
        if (Strings.equal(currentAccountType, "SAFE")) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
    }
}
