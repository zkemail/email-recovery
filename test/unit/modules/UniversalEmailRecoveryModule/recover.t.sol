// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ISafe7579 } from "safe7579/Safe7579.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract UniversalEmailRecoveryModule_recover_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RevertWhen_InvalidAccount() public {
        address invalidAccount = address(1);

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, functionSelector
            )
        );
        emailRecoveryModule.exposed_recover(invalidAccount, recoveryData);
    }

    function test_Recover_RevertWhen_InvalidCalldataSelector() public {
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory changeOwnerCalldata =
            abi.encodeWithSelector(invalidSelector, accountAddress, recoveryModuleAddress, newOwner);
        bytes memory invalidCalldata = abi.encode(accountAddress, changeOwnerCalldata);

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, invalidSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress, invalidCalldata);
    }

    function test_Recover_RevertWhen_InvalidZeroCalldataSelector() public {
        bytes memory invalidChangeOwnerCaldata = bytes("0x");
        bytes memory invalidCalldata = abi.encode(accountAddress, invalidChangeOwnerCaldata);

        bytes4 expectedSelector;
        assembly {
            expectedSelector := mload(add(invalidChangeOwnerCaldata, 32))
        }

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, expectedSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress, invalidCalldata);
    }

    function test_Recover_RevertWhen_CalldataWithoutValidator() public {
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory calldataWithoutValidator =
            abi.encodeWithSelector(invalidSelector, accountAddress, recoveryModuleAddress, newOwner);

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress, calldataWithoutValidator);
    }

    function test_Recover_RevertWhen_RecoveryDataWithTruncatedValidatorAddress() public {
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes memory invalidData = abi.encode(bytes8(bytes20(accountAddress)), validCalldata);

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress, invalidData);
    }

    function test_Recover_RevertWhen_ZeroValidatorAddress() public {
        address zeroValidator = address(0);
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes memory invalidData = abi.encode(zeroValidator, validCalldata);

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidValidator.selector, zeroValidator
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress, invalidData);
    }

    function test_Recover_RevertWhen_IncorrectValidatorAddress() public {
        address wrongValidator = accountAddress;
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes memory invalidData = abi.encode(accountAddress, validCalldata);
        console2.logBytes4(functionSelector);
        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                UniversalEmailRecoveryModule.InvalidSelector.selector, functionSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress, invalidData);
    }

    function test_Recover_Succeeds() public {
        vm.startPrank(recoveryModuleAddress);
        vm.expectEmit();
        emit UniversalEmailRecoveryModule.RecoveryExecuted(accountAddress, validatorAddress);
        emailRecoveryModule.exposed_recover(accountAddress, recoveryData);

        address updatedOwner = validator.owners(accountAddress);
        assertEq(updatedOwner, newOwner);
    }
}
