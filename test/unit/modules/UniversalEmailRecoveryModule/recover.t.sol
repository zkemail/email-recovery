// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
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

    function test_Recover_RevertWhen_EmptyCalldata() public {
        bytes memory emptyCalldata = bytes("");
        bytes memory invalidCalldata = abi.encode(accountAddress1, emptyCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        // This should revert due to unsafe memory access when reading recoveryData[96:100]
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress1, invalidCalldata);
    }

    function test_Recover_RevertWhen_CalldataLessThan4Bytes() public {
        // Create a scenario that triggers unsafe memory access
        // The implementation reads recoveryData[96:100] to get the selector
        // But if recoveryData is between 96-100 bytes, this will cause an out-of-bounds access

        // Create a bytes array with only 2 bytes (less than the 4 bytes needed for a selector)
        bytes memory shortCalldata = new bytes(2);
        shortCalldata[0] = 0x12;
        shortCalldata[1] = 0x34;

        // Encode this into recovery data format
        bytes memory recoveryData = abi.encode(accountAddress1, shortCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        // This should revert due to unsafe memory access when reading recoveryData[96:100]
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress1, recoveryData);
    }

    function test_Recover_RevertWhen_InvalidZeroCalldataSelector() public {
        bytes memory invalidChangeOwnerCalldata = bytes("0x");
        bytes memory invalidCalldata = abi.encode(accountAddress1, invalidChangeOwnerCalldata);

        bytes4 expectedSelector;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            expectedSelector := mload(add(invalidChangeOwnerCalldata, 32))
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
        address wrongValidator = address(1);
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

        address updatedOwner;
        if (isAccountTypeSafe()) {
            bool isOwner = Safe(payable(accountAddress1)).isOwner(newOwner1);
            assertTrue(isOwner);
        } else {
            updatedOwner = validator.owners(accountAddress1);
            assertEq(updatedOwner, newOwner1);
        }
    }
}
