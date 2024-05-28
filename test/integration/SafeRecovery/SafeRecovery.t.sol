// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";

import {MODULE_TYPE_EXECUTOR} from "erc7579/interfaces/IERC7579Module.sol";
import {IERC7579Account} from "erc7579/interfaces/IERC7579Account.sol";
import {Safe} from "@safe-global/safe-contracts/contracts/Safe.sol";

import {IEmailAccountRecovery} from "src/interfaces/IEmailAccountRecovery.sol";
import {SafeRecoveryModule} from "src/modules/SafeRecoveryModule.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {GuardianStorage, GuardianStatus} from "src/libraries/EnumerableGuardianMap.sol";
import {SafeIntegrationBase} from "./SafeIntegrationBase.t.sol";

contract SafeRecovery_Integration_Test is SafeIntegrationBase {
    SafeRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();
        recoveryModule = new SafeRecoveryModule(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);
    }

    function testRecover() public {
        IERC7579Account account = IERC7579Account(accountAddress);

        // Install recovery module - configureRecovery is called on `onInstall`
        vm.prank(accountAddress);
        account.installModule(
            MODULE_TYPE_EXECUTOR,
            recoveryModuleAddress,
            abi.encode(guardians, guardianWeights, threshold, delay, expiry)
        );
        vm.stopPrank();

        // Retrieve router now module has been installed
        address router = zkEmailRecovery.getRouterForAccount(accountAddress);

        // Accept guardian
        acceptGuardian(
            accountAddress,
            zkEmailRecovery,
            router,
            "Accept guardian request for 0xE760ccaE42b4EA7a93A4CfA75BC649aaE1033095",
            keccak256(abi.encode("nullifier 1")),
            accountSalt1,
            templateIdx
        );
        GuardianStorage memory guardianStorage1 = zkEmailRecovery.getGuardian(
            accountAddress,
            guardian1
        );
        assertEq(
            uint256(guardianStorage1.status),
            uint256(GuardianStatus.ACCEPTED)
        );
        assertEq(guardianStorage1.weight, uint256(1));

        // Accept guardian
        acceptGuardian(
            accountAddress,
            zkEmailRecovery,
            router,
            "Accept guardian request for 0xE760ccaE42b4EA7a93A4CfA75BC649aaE1033095",
            keccak256(abi.encode("nullifier 1")),
            accountSalt2,
            templateIdx
        );
        GuardianStorage memory guardianStorage2 = zkEmailRecovery.getGuardian(
            accountAddress,
            guardian2
        );
        assertEq(
            uint256(guardianStorage2.status),
            uint256(GuardianStatus.ACCEPTED)
        );
        assertEq(guardianStorage2.weight, uint256(1));

        // Time travel so that EmailAuth timestamp is valid
        vm.warp(12 seconds);

        // handle recovery request for guardian 1
        handleRecovery(
            accountAddress,
            owner,
            newOwner,
            recoveryModuleAddress,
            router,
            zkEmailRecovery,
            "Recover account 0xE760ccaE42b4EA7a93A4CfA75BC649aaE1033095 from old owner 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x6d2Fa6974Ef18eB6da842D3c7ab3150326feaEEC",
            keccak256(abi.encode("nullifier 2")),
            accountSalt1,
            templateIdx
        );
        IZkEmailRecovery.RecoveryRequest
            memory recoveryRequest = zkEmailRecovery.getRecoveryRequest(
                accountAddress
            );
        assertEq(recoveryRequest.currentWeight, 1);

        // handle recovery request for guardian 2
        uint256 executeAfter = block.timestamp + delay;
        uint256 executeBefore = block.timestamp + expiry;
        handleRecovery(
            accountAddress,
            owner,
            newOwner,
            recoveryModuleAddress,
            router,
            zkEmailRecovery,
            "Recover account 0xE760ccaE42b4EA7a93A4CfA75BC649aaE1033095 from old owner 0x7c8999dC9a822c1f0Df42023113EDB4FDd543266 to new owner 0x7240b687730BE024bcfD084621f794C2e4F8408f using recovery module 0x6d2Fa6974Ef18eB6da842D3c7ab3150326feaEEC",
            keccak256(abi.encode("nullifier 2")),
            accountSalt2,
            templateIdx
        );
        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, executeAfter);
        assertEq(recoveryRequest.executeBefore, executeBefore);
        assertEq(
            recoveryRequest.subjectParams,
            subjectParamsForRecovery(
                accountAddress,
                owner,
                newOwner,
                recoveryModuleAddress
            )
        );
        assertEq(recoveryRequest.currentWeight, 2);

        vm.warp(block.timestamp + delay);

        // Complete recovery
        IEmailAccountRecovery(router).completeRecovery();

        recoveryRequest = zkEmailRecovery.getRecoveryRequest(accountAddress);
        assertEq(recoveryRequest.executeAfter, 0);
        assertEq(recoveryRequest.executeBefore, 0);
        assertEq(recoveryRequest.subjectParams, new bytes[](0));
        assertEq(recoveryRequest.currentWeight, 0);

        vm.prank(accountAddress);
        bool isOwner = Safe(payable(accountAddress)).isOwner(newOwner);
        assertTrue(isOwner);

        bool oldOwnerIsOwner = Safe(payable(accountAddress)).isOwner(owner);
        assertFalse(oldOwnerIsOwner);
    }
}
