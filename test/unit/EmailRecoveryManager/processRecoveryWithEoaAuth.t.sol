// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { CommandHandlerType } from "../../Base.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { IEmailRecoveryCommandHandler } from "src/interfaces/IEmailRecoveryCommandHandler.sol";
import { GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { IGuardianManager } from "src/interfaces/IGuardianManager.sol";

/// @dev - This file is originally implemented in the EOA-TX-builder module.
//import { IEoaAuth } from "../../../src/interfaces/circuits/IEoaAuth.sol";
import { EoaProof } from "../../../src/eoa-auth/interfaces/circuits/IVerifier.sol";

/****
 * @notice - This is the test that utilize the EmailRecoveryManager#processRecoveryWithEoaAuth(), which the EoaAuth.sol is used.
 ***/
contract EmailRecoveryManager_processRecoveryWithEoaAuth_Test is UnitBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    string public recoveryDataHashString;
    bytes[] public commandParams;
    bytes32 public nullifier;

    EoaProof public proof;            /// [TODO]: Store some value of a proof-generated for the test into here.
    uint256[34] public pubSignals;    /// [TODO]: Store some value of a public signals for the test into here.

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

    function test_ProcessRecovery_RevertWhen_KillSwitchEnabled() public {
        vm.prank(killSwitchAuthorizer);
        emailRecoveryModule.toggleKillSwitch();
        vm.stopPrank();

        vm.expectRevert(IGuardianManager.KillSwitchEnabled.selector);
        emailRecoveryModule.exposed_processRecoveryWithEoaAuth( /// @dev - UniversalEmailRecoveryModuleHarness# exposed_processRecovery()
            guardians1[0], templateIdx, commandParams, nullifier, proof, pubSignals /// @dev - "proof" and "pubSignals" are added to the parameters.
            //guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecoveryWithEoaAuth_RevertWhen_GuardianStatusIsNONE() public {
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
        emailRecoveryModule.exposed_processRecoveryWithEoaAuth(
            guardians1[0], templateIdx, commandParams, nullifier, proof, pubSignals /// @dev - "proof" and "pubSignals" are added to the parameters.
            //invalidGuardian, templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecoveryWithEoaAuth_RevertWhen_GuardianStatusIsREQUESTED() public {
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
        emailRecoveryModule.exposed_processRecoveryWithEoaAuth(
            guardians1[0], templateIdx, commandParams, nullifier, proof, pubSignals /// @dev - "proof" and "pubSignals" are added to the parameters.
            //guardians1[0], templateIdx, commandParams, nullifier
        );
    }

    function test_ProcessRecoveryWithEoaAuth_IncreasesTotalWeight() public {
        uint256 guardian1Weight = guardianWeights[0];

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);

        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryRequestStarted(
            accountAddress1, guardians1[0], block.timestamp + expiry, recoveryDataHash
        );
        emailRecoveryModule.exposed_processRecoveryWithEoaAuth(
            guardians1[0], templateIdx, commandParams, nullifier, proof, pubSignals /// @dev - "proof" and "pubSignals" are added to the parameters.
            //guardians1[0], templateIdx, commandParams, nullifier
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

    function test_ProcessRecoveryWithEoaAuth_InitiatesRecovery() public {
        uint256 guardian1Weight = guardianWeights[0];
        uint256 guardian2Weight = guardianWeights[1];

        acceptGuardian(accountAddress1, guardians1[0], emailRecoveryModuleAddress);
        acceptGuardian(accountAddress1, guardians1[1], emailRecoveryModuleAddress);
        vm.warp(12 seconds);
        // Call processRecovery - increases currentWeight to 1 so not >= threshold yet

        vm.expectEmit();
        emit IEmailRecoveryManager.GuardianVoted(
            accountAddress1, guardians1[0], guardian1Weight, guardian1Weight
        );
        emailRecoveryModule.exposed_processRecoveryWithEoaAuth(
            guardians1[0], templateIdx, commandParams, nullifier, proof, pubSignals /// @dev - "proof" and "pubSignals" are added to the parameters.
            //guardians1[0], templateIdx, commandParams, nullifier
        );

        // Call processRecovery with guardians2 which increases currentWeight to >= threshold
        vm.expectEmit();
        emit IEmailRecoveryManager.RecoveryRequestComplete(
            accountAddress1,
            guardians1[1],
            block.timestamp + delay,
            block.timestamp + expiry,
            recoveryDataHash
        );
        emailRecoveryModule.exposed_processRecoveryWithEoaAuth(
            guardians1[0], templateIdx, commandParams, nullifier, proof, pubSignals /// @dev - "proof" and "pubSignals" are added to the parameters.
            //guardians1[1], templateIdx, commandParams, nullifier
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
