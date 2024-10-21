// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { SafeNativeIntegrationBase } from
    "../../../integration/SafeRecovery/SafeNativeIntegrationBase.t.sol";

contract SafeEmailRecoveryModule_recover_Test is SafeNativeIntegrationBase {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RevertWhen_InvalidCalldataSelector() public {
        skipIfNotSafeAccountType();
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory invalidCalldata = abi.encodeWithSelector(
            invalidSelector, accountAddress1, emailRecoveryModuleAddress, newOwner1
        );
        bytes memory invalidData = abi.encode(accountAddress1, invalidCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeEmailRecoveryModule.InvalidSelector.selector, invalidSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidData);
    }

    function test_Recover_RevertWhen_InvalidZeroCalldataSelector() public {
        skipIfNotSafeAccountType();
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
                SafeEmailRecoveryModule.InvalidSelector.selector, expectedSelector
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidCalldata);
    }

    function test_Recover_RevertWhen_CalldataWithoutValidator() public {
        skipIfNotSafeAccountType();
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory calldataWithoutValidator = abi.encodeWithSelector(
            invalidSelector, accountAddress1, emailRecoveryModuleAddress, newOwner1
        );

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress1, calldataWithoutValidator);
    }

    function test_Recover_RevertWhen_RecoveryDataWithTruncatedValidatorAddress() public {
        skipIfNotSafeAccountType();
        bytes memory validCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory invalidData = abi.encode(bytes8(bytes20(accountAddress1)), validCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert();
        emailRecoveryModule.exposed_recover(accountAddress1, invalidData);
    }

    function test_Recover_RevertWhen_RecoveryFailed() public {
        skipIfNotSafeAccountType();
        bytes memory invalidCalldata = abi.encodeWithSelector(functionSelector, accountAddress1);
        bytes memory invalidData = abi.encode(accountAddress1, invalidCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeEmailRecoveryModule.RecoveryFailed.selector, accountAddress1, bytes("")
            )
        );
        emailRecoveryModule.exposed_recover(accountAddress1, invalidData);
    }

    function test_Recover_DoesNotRevertWhen_ZeroAddress() public {
        skipIfNotSafeAccountType();
        bytes memory dataWithZeroAddress = abi.encode(address(0), recoveryCalldata);

        vm.startPrank(emailRecoveryModuleAddress);
        emailRecoveryModule.exposed_recover(accountAddress1, dataWithZeroAddress);
    }

    function test_Recover_Succeeds() public {
        skipIfNotSafeAccountType();
        vm.startPrank(emailRecoveryModuleAddress);
        vm.expectEmit();
        emit SafeEmailRecoveryModule.RecoveryExecuted(accountAddress1);
        emailRecoveryModule.exposed_recover(accountAddress1, recoveryData);

        bool isOwner = Safe(payable(accountAddress1)).isOwner(newOwner1);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(accountAddress1)).isOwner(owner1);
        assertFalse(oldOwnerIsOwner);
    }
}
