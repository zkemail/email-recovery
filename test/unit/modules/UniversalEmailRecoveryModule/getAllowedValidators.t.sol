// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { SentinelListHelper } from "sentinellist/SentinelListHelper.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_getAllowedValidators_Test is UnitBase {
    using ModuleKitHelpers for *;
    using SentinelListHelper for address[];

    function setUp() public override {
        super.setUp();
    }

    function test_GetAllowedValidators_SucceedsWhenNoValidators() public {
        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);
        address prevValidator = allowedValidators.findPrevious(validatorAddress);

        vm.startPrank(accountAddress1);
        emailRecoveryModule.disallowValidatorRecovery(
            validatorAddress, prevValidator, functionSelector
        );
        vm.stopPrank();

        allowedValidators = emailRecoveryModule.getAllowedValidators(accountAddress1);

        assertEq(allowedValidators.length, 0);
    }

    function test_GetAllowedValidators_SucceedsWithOneValidator() public view {
        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);

        assertEq(allowedValidators.length, 1);
        assertEq(allowedValidators[0], validatorAddress);
    }

    function test_GetAllowedValidators_SucceedsMultipleValidators() public {
        // Deplopy and install new validator
        OwnableValidator newValidator = new OwnableValidator();
        address newValidatorAddress = address(newValidator);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: newValidatorAddress,
            data: abi.encode(owner1)
        });
        bytes4 newFunctionSelector = bytes4(keccak256(bytes("rotateOwner(address,address)")));

        vm.startPrank(accountAddress1);
        emailRecoveryModule.allowValidatorRecovery(newValidatorAddress, "", newFunctionSelector);
        vm.stopPrank();

        address[] memory allowedValidators =
            emailRecoveryModule.getAllowedValidators(accountAddress1);
        assertEq(allowedValidators.length, 2);
        assertEq(allowedValidators[0], newValidatorAddress);
        assertEq(allowedValidators[1], validatorAddress);
    }
}
