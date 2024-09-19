// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_recover_Test is EmailRecoveryModuleBase {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RevertWhen_InvalidCalldataSelector() public {
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory invalidCalldata = abi.encodeWithSelector(
            invalidSelector, accountAddress1, emailRecoveryModuleAddress, newOwner1
        );
        bytes memory invalidData = abi.encode(accountAddress1, invalidCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidSelector.selector, invalidSelector)
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidData);
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
            abi.encodeWithSelector(EmailRecoveryModule.InvalidSelector.selector, expectedSelector)
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

    function test_Recover_DoesNotRevertWhen_ZeroAddress() public {
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory dataWithZeroAddress = abi.encode(address(0), validCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        emailRecoveryModule.exposed_recover(accountAddress1, dataWithZeroAddress);
    }

    function test_Recover_Succeeds() public {
        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectEmit();
        emit EmailRecoveryModule.RecoveryExecuted(accountAddress1, validatorAddress);
        emailRecoveryModule.exposed_recover(accountAddress1, recoveryData);

        address updatedOwner = validator.owners(accountAddress1);
        assertEq(updatedOwner, newOwner1);
    }
}
