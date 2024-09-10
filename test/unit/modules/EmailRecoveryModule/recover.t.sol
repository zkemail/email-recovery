// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
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
        bytes memory invalidCalldata =
            abi.encodeWithSelector(invalidSelector, accountAddress, recoveryModuleAddress, newOwner);
        bytes memory invalidData = abi.encode(accountAddress, invalidCalldata);

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidSelector.selector, invalidSelector)
        );
        emailRecoveryModule.exposed_recover(accountAddress, invalidData);
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
            abi.encodeWithSelector(EmailRecoveryModule.InvalidSelector.selector, expectedSelector)
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

    function test_Recover_DoesNotRevertWhen_ZeroAddress() public {
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner);
        bytes memory dataWithZeroAddress = abi.encode(address(0), validCalldata);

        vm.startPrank(recoveryModuleAddress);
        emailRecoveryModule.exposed_recover(accountAddress, dataWithZeroAddress);
    }

    function test_Recover_Succeeds() public {
        vm.startPrank(recoveryModuleAddress);
        vm.expectEmit();
        emit EmailRecoveryModule.RecoveryExecuted(accountAddress, validatorAddress);
        emailRecoveryModule.exposed_recover(accountAddress, recoveryData);

        address updatedOwner = validator.owners(accountAddress);
        assertEq(updatedOwner, newOwner);
    }
}
