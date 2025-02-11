// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CommandHandlerType } from "../../../Base.t.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract EmailRecoveryModule_acceptGuardian_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    bytes[] public commandParams;
    bytes32 public nullifier;

    address owner = vm.addr(2);
    address nonOwner = address(0x2);
    address testAccount = address(0x3);

    function setUp() public override {
        super.setUp();

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            commandParams = new bytes[](1);
            commandParams[0] =
                abi.encode(uint256(keccak256(abi.encodePacked(accountAddress1))).toHexString(32));
        } else {
            commandParams = new bytes[](1);
            commandParams[0] = abi.encode(accountAddress1);
        }

        nullifier = keccak256(abi.encode("nullifier 1"));
    }

    function test_RevertsWhenTransactionInitiatorNotSet() public {
        vm.startPrank(owner);
        vm.expectRevert("Only allowed accounts can call this function");
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
        vm.stopPrank();
    }

    function test_FailsWhenExactly6MonthsMinus1Second() public {
        vm.warp(emailRecoveryModule.deploymentTimestamp() + 6 * 30 days - 1 seconds);

        vm.startPrank(testAccount);
        vm.expectRevert("Only allowed accounts can call this function");
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
        vm.stopPrank();
    }

    function test_SucceedsWhenTransactionInitiatorIsSet() public {
        vm.prank(owner);
        emailRecoveryModule.setTransactionInitiator(testAccount, true);

        vm.prank(testAccount);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_SucceedsWhenExactly6Months() public {
        vm.warp(emailRecoveryModule.deploymentTimestamp() + 6 * 30 days);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_SucceedsWhenExactly6MonthsPlus1Second() public {
        vm.warp(emailRecoveryModule.deploymentTimestamp() + 6 * 30 days + 1 seconds);
        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_SucceedsWhenZeroAddressForTransactionInitiatorIsSetToTrue() public {
        vm.prank(owner);
        emailRecoveryModule.setTransactionInitiator(address(0), true);

        emailRecoveryModule.exposed_acceptGuardian(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }
}
