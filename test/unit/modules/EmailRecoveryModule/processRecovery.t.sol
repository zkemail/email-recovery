// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { EmailRecoveryModuleBase } from "./EmailRecoveryModuleBase.t.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { CommandHandlerType } from "../../../Base.t.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract EmailRecoveryModule_processRecovery_Test is EmailRecoveryModuleBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    string public recoveryDataHashString;
    bytes[] public commandParams;
    bytes32 public nullifier;

    address owner = vm.addr(2);
    address nonOwner = address(0x2);
    address testAccount = address(0x3);

    function setUp() public override {
        super.setUp();

        if (getCommandHandlerType() == CommandHandlerType.EmailRecoveryCommandHandler) {
            recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
            commandParams = new bytes[](2);
            commandParams[0] = abi.encode(accountAddress1);
            commandParams[1] = abi.encode(recoveryDataHashString);
        }
        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
            commandParams = new bytes[](2);
            commandParams[0] =
                abi.encode(uint256(keccak256(abi.encodePacked(accountAddress1))).toHexString(32));
            commandParams[1] = abi.encode(recoveryDataHashString);
        }
        if (getCommandHandlerType() == CommandHandlerType.SafeRecoveryCommandHandler) {
            commandParams = new bytes[](3);
            commandParams[0] = abi.encode(accountAddress1);
            commandParams[1] = abi.encode(owner1);
            commandParams[2] = abi.encode(newOwner1);
        }

        nullifier = keccak256(abi.encode("nullifier 1"));
    }

    function test_RevertsWhenTransactionInitiatorNotSet() public {
        vm.startPrank(testAccount);
        vm.expectRevert("Only allowed accounts can call this function");
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
        vm.stopPrank();
    }

    function test_FailsWhenExactly6MonthsMinus1Second() public {
        vm.startPrank(testAccount);
        vm.warp(emailRecoveryModule.deploymentTimestamp() + 6 * 30 days - 1 seconds);
        vm.expectRevert("Only allowed accounts can call this function");
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
        vm.stopPrank();
    }

    function test_SucceedsWhenTransactionInitiatorIsSet() public {
        vm.startPrank(owner);
        emailRecoveryModule.setTransactionInitiator(testAccount, true);
        vm.stopPrank();

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.prank(testAccount);
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_SucceedsWhenExactly6Months() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.warp(emailRecoveryModule.deploymentTimestamp() + 6 * 30 days);
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_SucceedsWhenExactly6MonthsPlus1Second() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.warp(emailRecoveryModule.deploymentTimestamp() + 6 * 30 days + 1 seconds);
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_SucceedsWhenZeroAddressForTransactionInitiatorIsSetToTrue() public {
        vm.prank(owner);
        emailRecoveryModule.setTransactionInitiator(address(0), true);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.startPrank(testAccount);
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
        vm.stopPrank();
    }
}
