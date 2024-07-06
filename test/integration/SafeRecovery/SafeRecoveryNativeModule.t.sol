// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "erc7579/interfaces/IERC7579Module.sol";
import { IERC7579Account } from "erc7579/interfaces/IERC7579Account.sol";
import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { SafeProxy } from "@safe-global/safe-contracts/contracts/proxies/SafeProxy.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { SafeNativeIntegrationBase } from "./SafeNativeIntegrationBase.t.sol";

contract SafeRecoveryNativeModule_Integration_Test is SafeNativeIntegrationBase {
    function setUp() public override {
        super.setUp();
    }

    function testIntegration_AccountRecovery() public {
        bool moduleEnabled = safe.isModuleEnabled(address(safeEmailRecoveryModule));

        address newOwner = owner2;

        // Configure recovery
        vm.startPrank(safeAddress);
        safeEmailRecoveryModule.configureRecovery(
            guardians1, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        bytes memory recoveryCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", address(1), owner, newOwner
        );
        bytes32 calldataHash = keccak256(recoveryCalldata);

        bytes[] memory subjectParamsForRecovery = new bytes[](4);
        subjectParamsForRecovery[0] = abi.encode(safeAddress);
        subjectParamsForRecovery[1] = abi.encode(owner);
        subjectParamsForRecovery[2] = abi.encode(newOwner);
        subjectParamsForRecovery[3] = abi.encode(address(safeEmailRecoveryModule));

        // Accept guardian
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(safeAddress, guardians1[0]);
        safeEmailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        GuardianStorage memory guardianStorage1 =
            safeEmailRecoveryModule.getGuardian(safeAddress, guardians1[0]);
        assertEq(uint256(guardianStorage1.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian
        emailAuthMsg = getAcceptanceEmailAuthMessage(safeAddress, guardians1[1]);
        safeEmailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
        GuardianStorage memory guardianStorage2 =
            safeEmailRecoveryModule.getGuardian(safeAddress, guardians1[1]);
        assertEq(uint256(guardianStorage2.status), uint256(GuardianStatus.ACCEPTED));
        assertEq(guardianStorage2.weight, uint256(2));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        emailAuthMsg = getRecoveryEmailAuthMessage(safeAddress, owner, newOwner, guardians1[0]);
        safeEmailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        IEmailRecoveryManager.RecoveryRequest memory recoveryRequest =
            safeEmailRecoveryModule.getRecoveryRequest(safeAddress);
        assertEq(recoveryRequest.currentWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        emailAuthMsg = getRecoveryEmailAuthMessage(safeAddress, owner, newOwner, guardians1[1]);
        safeEmailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
        recoveryRequest = safeEmailRecoveryModule.getRecoveryRequest(safeAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(recoveryRequest.currentWeight, 3);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        safeEmailRecoveryModule.completeRecovery(safeAddress, recoveryCalldata);

        recoveryRequest = safeEmailRecoveryModule.getRecoveryRequest(safeAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.currentWeight, 0);

        vm.prank(safeAddress);
        bool isOwner = Safe(payable(safeAddress)).isOwner(newOwner);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(safeAddress)).isOwner(owner);
        assertFalse(oldOwnerIsOwner);
    }
}
