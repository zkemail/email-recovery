// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";

import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {UnitBase} from "../UnitBase.t.sol";

contract ZkEmailRecovery_configureRecovery_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    // function test_RevertWhen_AlreadyRecovering() public {
    //     address accountAddress = address(safe);
    //     vm.startPrank(accountAddress);
    //     safeZkEmailRecovery.configureRecovery(
    //         recoveryModuleAddress,
    //         guardians,
    //         guardianWeights,
    //         threshold,
    //         delay,
    //         expiry
    //     );
    //     vm.stopPrank();

    //     address router = safeZkEmailRecovery.getRouterForAccount(
    //         accountAddress
    //     );

    //     acceptGuardian(
    //         accountAddress,
    //         safeZkEmailRecovery,
    //         router,
    //         "Accept guardian request for 0x4DBa14a50681F152EE0b74fB00e7b2b0B8e3949a",
    //         keccak256(abi.encode("nullifier 1")),
    //         accountSalt1,
    //         templateIdx
    //     );

    //     // Time travel so that EmailAuth timestamp is valid
    //     vm.warp(12 seconds);

    //     // handle recovery request for guardian
    //     handleRecovery(
    //         accountAddress,
    //         owner,
    //         newOwner,
    //         recoveryModuleAddress,
    //         router,
    //         safeZkEmailRecovery,
    //         "Recover account 0x4DBa14a50681F152EE0b74fB00e7b2b0B8e3949a from old owner 0x7C8913d493892928d19F932FB1893404b6f1cE73 to new owner 0x11A5669986B1fCBfcE54be4c543975b33D89856D using recovery module 0x1fC14F21b27579f4F23578731cD361CCa8aa39f7",
    //         keccak256(abi.encode("nullifier 2")),
    //         accountSalt1,
    //         templateIdx
    //     );

    //     vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
    //     vm.startPrank(accountAddress);
    //     safeZkEmailRecovery.configureRecovery(
    //         recoveryModuleAddress,
    //         guardians,
    //         guardianWeights,
    //         threshold,
    //         delay,
    //         expiry
    //     );
    //     vm.stopPrank();
    // }

    // function test_ConfigureRecovery_Succeeds() public {
    //     address accountAddress = address(safe);

    //     address expectedRouterAddress = safeZkEmailRecovery
    //         .computeRouterAddress(keccak256(abi.encode(accountAddress)));

    //     vm.expectEmit();
    //     emit IZkEmailRecovery.RecoveryConfigured(
    //         accountAddress,
    //         recoveryModuleAddress,
    //         guardians.length,
    //         expectedRouterAddress
    //     );
    //     vm.startPrank(accountAddress);
    //     safeZkEmailRecovery.configureRecovery(
    //         recoveryModuleAddress,
    //         guardians,
    //         guardianWeights,
    //         threshold,
    //         delay,
    //         expiry
    //     );
    //     vm.stopPrank();

    //     IZkEmailRecovery.RecoveryConfig
    //         memory recoveryConfig = safeZkEmailRecovery.getRecoveryConfig(
    //             accountAddress
    //         );
    //     assertEq(recoveryConfig.recoveryModule, recoveryModuleAddress);
    //     assertEq(recoveryConfig.delay, delay);
    //     assertEq(recoveryConfig.expiry, expiry);

    //     IZkEmailRecovery.GuardianConfig
    //         memory guardianConfig = safeZkEmailRecovery.getGuardianConfig(
    //             accountAddress
    //         );
    //     assertEq(guardianConfig.guardianCount, guardians.length);
    //     assertEq(guardianConfig.threshold, threshold);

    //     IZkEmailRecovery.GuardianStorage memory guardian = safeZkEmailRecovery
    //         .getGuardian(accountAddress, guardians[0]);
    //     assertEq(
    //         uint256(guardian.status),
    //         uint256(IZkEmailRecovery.GuardianStatus.REQUESTED)
    //     );
    //     assertEq(guardian.weight, guardianWeights[0]);

    //     address accountForRouter = safeZkEmailRecovery.getAccountForRouter(
    //         expectedRouterAddress
    //     );
    //     assertEq(accountForRouter, accountAddress);

    //     address routerForAccount = safeZkEmailRecovery.getRouterForAccount(
    //         accountAddress
    //     );
    //     assertEq(routerForAccount, expectedRouterAddress);
    // }
}
