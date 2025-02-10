// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract EmailRecoveryModule_setTransactionInitiator_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;

    address owner = vm.addr(2);
    address nonOwner = address(0x2);
    address testAccount = address(0x3);

    function setUp() public override {
        super.setUp();
    }

    function test_RevertsIfNotOwner() public {
        vm.prank(nonOwner);
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, nonOwner)
        );
        emailRecoveryModule.setTransactionInitiator(owner, true);
    }

    function test_SetsNonZeroAddressToTrue() public {
        vm.prank(owner);
        emailRecoveryModule.setTransactionInitiator(testAccount, true);
    }

    function test_SetsNonZeroAddressToFalseAfterTrue() public {
        vm.startPrank(owner);
        emailRecoveryModule.setTransactionInitiator(testAccount, true);

        emailRecoveryModule.setTransactionInitiator(testAccount, false);
        vm.stopPrank();
    }

    function test_SetsZeroAddressToTrue() public {
        vm.prank(owner);
        emailRecoveryModule.setTransactionInitiator(address(0), true);
    }

    function test_SetsZeroAddressToFalseAfterTrue() public {
        vm.startPrank(owner);
        emailRecoveryModule.setTransactionInitiator(address(0), true);

        emailRecoveryModule.setTransactionInitiator(address(0), false);
        vm.stopPrank();
    }
}
