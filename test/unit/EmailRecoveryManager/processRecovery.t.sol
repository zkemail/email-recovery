// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { CommandHandlerType } from "../../Base.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IEmailRecoveryCommandHandler } from "src/interfaces/IEmailRecoveryCommandHandler.sol";
import { GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";

contract EmailRecoveryManager_processRecovery_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;

    string public recoveryDataHashString;
    bytes[] public commandParams;
    bytes32 public nullifier;

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

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsNONE() public {
        address invalidGuardian = address(1);

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        // invalidGuardian has not been configured nor accepted, so the guardian status is NONE
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.NONE),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            invalidGuardian, templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianStatusIsREQUESTED() public {
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[2], emailRecoveryModuleAddress);

        // Valid guardian but we haven't called acceptGuardian(), so the guardian
        // status is still REQUESTED
        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidGuardianStatus.selector,
                uint256(GuardianStatus.REQUESTED),
                uint256(GuardianStatus.ACCEPTED)
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_RecoveryModuleNotInstalled() public {
        instance1.uninstallModule(MODULE_TYPE_EXECUTOR, emailRecoveryModuleAddress, "");

        vm.expectRevert(IEmailRecoveryManager.RecoveryIsNotActivated.selector);
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_ThresholdExceedsAcceptedWeight() public {
        // total weight = 4
        // threshold = 3
        // useable weight from accepted guardians = 0

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress); // weight = 1
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress); // weight = 2

        // total weight = 4
        // threshold = 3
        // useable weight from accepted guardians = 3

        address newGuardian = address(1);
        uint256 newWeight = 1;
        uint256 newThreshold = 5;

        vm.startPrank(accountAddress1);
        emailRecoveryModule.addGuardian(newGuardian, newWeight);
        emailRecoveryModule.changeThreshold(newThreshold);
        vm.stopPrank();
        // total weight = 5
        // threshold = 5
        // useable weight from accepted guardians = 3

        vm.warp(12 seconds);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.ThresholdExceedsAcceptedWeight.selector, newThreshold, 3
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianAlreadyVoted() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.expectRevert(IEmailRecoveryManager.GuardianAlreadyVoted.selector);
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_InvalidRecoveryDataHash() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        bytes32 invalidRecoveryDataHash;
        if (getCommandHandlerType() == CommandHandlerType.SafeRecoveryCommandHandler) {
            address invalidOwner = address(1);
            commandParams[2] = abi.encode(invalidOwner);
            invalidRecoveryDataHash = IEmailRecoveryCommandHandler(commandHandlerAddress)
                .parseRecoveryDataHash(templateIdx, commandParams);
        } else {
            invalidRecoveryDataHash = keccak256(abi.encode("invalid hash"));
            string memory invalidRecoveryDataHashString =
                uint256(invalidRecoveryDataHash).toHexString(32);
            commandParams[1] = abi.encode(invalidRecoveryDataHashString);
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.InvalidRecoveryDataHash.selector,
                invalidRecoveryDataHash,
                recoveryDataHash
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianMustWaitForCooldown() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.warp(block.timestamp + expiry);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.GuardianMustWaitForCooldown.selector, guardians1[0]
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianMustWaitForCooldown_GuardianCountIsTwo()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        // remove guardian 3
        vm.startPrank(accountAddress1);
        emailRecoveryModule.removeGuardian(guardians1[2]);
        vm.stopPrank();

        uint256 guardianCount = emailRecoveryModule.getGuardianConfig(accountAddress1).guardianCount;
        assertEq(guardianCount, 2);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.warp(block.timestamp + expiry);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.GuardianMustWaitForCooldown.selector, guardians1[0]
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_RevertWhen_GuardianMustWaitForCooldown_CooldownOneSecondRemaining(
    )
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.warp(block.timestamp + expiry);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        // warp to after cooldown has expired
        vm.warp(
            block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN() - 1 seconds
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IEmailRecoveryManager.GuardianMustWaitForCooldown.selector, guardians1[0]
            )
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecovery_PreviousGuardianInitiatedButCooldownOver() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.warp(block.timestamp + expiry);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        // warp to after cooldown has expired + 1 seconds
        vm.warp(
            block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN() + 1 seconds
        );

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, guardianWeights[0]);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, block.timestamp - 1 seconds);
        assertEq(hasGuardian1Voted, true);
    }

    function test_ProcessRecovery_PreviousGuardianInitiatedButCooldownOver_CooldownIsEqual()
        public
    {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        vm.warp(block.timestamp + expiry);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        // warp to after cooldown has expired - cooldown end is equal to timestamp
        vm.warp(block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN());

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, guardianWeights[0]);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(previousRecoveryRequest.cancelRecoveryCooldown, block.timestamp);
        assertEq(hasGuardian1Voted, true);
    }

    function test_ProcessRecovery_PreviousGuardianInitiatedButGuardianCountIsOne() public {
        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        // remove guardians 1 & 3
        vm.startPrank(accountAddress1);
        emailRecoveryModule.changeThreshold(2);
        emailRecoveryModule.removeGuardian(guardians1[0]);
        emailRecoveryModule.removeGuardian(guardians1[2]);
        vm.stopPrank();

        uint256 guardianCount = emailRecoveryModule.getGuardianConfig(accountAddress1).guardianCount;
        assertEq(guardianCount, 1);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );

        vm.warp(block.timestamp + expiry);
        emailRecoveryModule.cancelExpiredRecovery(accountAddress1);

        // guardian count is 1, so processRecovery can be executed subsequently by the same guardian
        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, block.timestamp + delay);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, guardianWeights[1]);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[1]);
        assertEq(
            previousRecoveryRequest.cancelRecoveryCooldown,
            block.timestamp + emailRecoveryModule.CANCEL_EXPIRED_RECOVERY_COOLDOWN()
        );
        assertEq(hasGuardian2Voted, true);
    }

    function test_ProcessRecovery_IncreasesTotalWeight() public {
        uint256 guardian1Weight = guardianWeights[0];

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        emailRecoveryModule.exposed_processRecovery(
            guardians1[0], templateIdx, commandParams, nullifier
        );

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, 0);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, guardian1Weight);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, false);
    }

    function test_ProcessRecovery_InitiatesRecovery() public {
        uint256 guardian1Weight = guardianWeights[0];
        uint256 guardian2Weight = guardianWeights[1];

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        // Call processRecovery - increases currentWeight to 1 so not >= threshold yet
        handleRecovery(accountAddress1, guardians1[0], recoveryDataHash, emailRecoveryModuleAddress);

        // Call processRecovery with guardians2 which increases currentWeight to >= threshold
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryProcessed(
            accountAddress1,
            guardians1[1],
            block.timestamp + delay,
            block.timestamp + expiry,
            recoveryDataHash
        );
        emailRecoveryModule.exposed_processRecovery(
            guardians1[1], templateIdx, commandParams, nullifier
        );

        (
            uint256 executeAfter,
            uint256 executeBefore,
            uint256 currentWeight,
            bytes32 _recoveryDataHash
        ) = emailRecoveryModule.getRecoveryRequest(accountAddress1);
        IEmailRecoveryManager.PreviousRecoveryRequest memory previousRecoveryRequest =
            emailRecoveryModule.getPreviousRecoveryRequest(accountAddress1);
        bool hasGuardian1Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[0]);
        bool hasGuardian2Voted =
            emailRecoveryModule.hasGuardianVoted(accountAddress1, guardians1[1]);
        assertEq(executeAfter, block.timestamp + delay);
        assertEq(executeBefore, block.timestamp + expiry);
        assertEq(currentWeight, guardian1Weight + guardian2Weight);
        assertEq(_recoveryDataHash, recoveryDataHash);
        assertEq(previousRecoveryRequest.previousGuardianInitiated, guardians1[0]);
        assertEq(hasGuardian1Voted, true);
        assertEq(hasGuardian2Voted, true);
    }
}
