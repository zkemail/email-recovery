// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_recover_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RevertWhen_InvalidAccount() public {
        address invalidAccount = address(1);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, functionSelector
            )
        );
        emailRecoveryModule.exposed_recover(invalidAccount, recoveryData);
    }

    function test_Recover_RevertWhen_InvalidCalldataSelector() public {
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory changeOwnerCalldata = abi.encodeWithSelector(
            invalidSelector, accountAddress1, emailRecoveryModuleAddress, newOwner1
        );
        bytes memory invalidCalldata = abi.encode(accountAddress1, changeOwnerCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, invalidSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidCalldata);
    }

    function test_Recover_RevertWhen_InvalidZeroCalldataSelector() public {
        bytes memory invalidChangeOwnerCaldata = bytes("0x");
        bytes memory invalidCalldata = abi.encode(accountAddress1, invalidChangeOwnerCaldata);

        bytes4 expectedSelector;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            expectedSelector := mload(add(invalidChangeOwnerCaldata, 32))
        }

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, expectedSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidCalldata);
    }

    function test_Recover_RevertWhen_CalldataWithoutValidator() public {
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory calldataWithoutValidator = abi.encodeWithSelector(
            invalidSelector, accountAddress1, emailRecoveryModuleAddress, newOwner1
        );

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress1, calldataWithoutValidator);
    }

    function test_Recover_RevertWhen_RecoveryDataWithTruncatedValidatorAddress() public {
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory invalidData = abi.encode(bytes8(bytes20(accountAddress1)), validCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress1, invalidData);
    }

    function test_Recover_RevertWhen_ZeroValidatorAddress() public {
        address zeroValidator = address(0);
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory invalidData = abi.encode(zeroValidator, validCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidValidator.selector, zeroValidator
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidData);
    }

    function test_Recover_RevertWhen_IncorrectValidatorAddress() public {
        address wrongValidator = accountAddress1;
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory invalidData = abi.encode(wrongValidator, validCalldata);
        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, functionSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidData);
    }

    function test_Recover_Succeeds() public {
        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectEmit();
        emit UniversalEmailRecoveryModule.RecoveryExecuted(accountAddress1, validatorAddress);
        emailRecoveryModule.exposed_recover(accountAddress1, recoveryData);

        address updatedOwner = validator.owners(accountAddress1);
        assertEq(updatedOwner, newOwner1);
    }
}
