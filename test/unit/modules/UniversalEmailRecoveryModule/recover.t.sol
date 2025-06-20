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

        // Create a recoveryData that's between 96-100 bytes total
        // We need to manually construct this to avoid ABI encoding padding

        // ABI encoding of (address, bytes) requires at least:
        // - 32 bytes: address
        // - 32 bytes: offset to calldata (64 = 0x40)
        // - 32 bytes: length of calldata (2 = 0x02)
        // - calldata bytes (2 bytes)
        // Total: 96 bytes + calldata length (2 bytes) = 98 bytes

        // Create a recoveryData that's exactly 98 bytes (between 96-100)
        // This will cause recoveryData[96:100] to read beyond the available data
        bytes memory recoveryData = new bytes(98);

        // Read state variable into local variable for assembly
        address validatorAddr = accountAddress1;

        // Set the validator address in the first 32 bytes
        assembly {
            mstore(add(recoveryData, 32), validatorAddr)
        }

        // Set the offset to calldata (64 = 0x40) in the next 32 bytes
        assembly {
            mstore(add(recoveryData, 64), 64)
        }

        // Set a calldata length that makes total length 98 bytes
        // 98 = 32 + 32 + 32 + calldata_length
        // calldata_length = 98 - 96 = 2 bytes
        assembly {
            mstore(add(recoveryData, 96), 2) // Only 2 bytes of calldata
        }

        // Set 2 bytes of calldata at position 96-97
        recoveryData[96] = 0x12;
        recoveryData[97] = 0x34;

        // Now recoveryData[96:100] tries to read 4 bytes starting at position 96
        // But we only have 98 bytes total, so positions 98-99 are out of bounds

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
