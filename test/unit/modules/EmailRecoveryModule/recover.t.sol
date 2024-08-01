// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";

contract EmailRecoveryModule_recover_Test is EmailRecoveryModuleBase {
    function setUp() public override {
        super.setUp();
    }

    function test_Recover_RevertWhen_InvalidCalldataSelector() public {
        bytes4 invalidSelector = bytes4(keccak256(bytes("wrongSelector(address,address,address)")));
        bytes memory invalidCalldata =
            abi.encodeWithSelector(invalidSelector, accountAddress, recoveryModuleAddress, newOwner);

        vm.startPrank(recoveryModuleAddress);
        vm.expectRevert(
            abi.encodeWithSelector(EmailRecoveryModule.InvalidSelector.selector, invalidSelector)
        );
        emailRecoveryModule.exposed_recover(accountAddress, invalidCalldata);
    }

    function test_Recover_Succeeds() public {
        vm.startPrank(recoveryModuleAddress);
        vm.expectEmit();
        emit EmailRecoveryModule.RecoveryExecuted(accountAddress, validatorAddress);
        emailRecoveryModule.exposed_recover(accountAddress, recoveryCalldata);

        address updatedOwner = validator.owners(accountAddress);
        assertEq(updatedOwner, newOwner);
    }
}
