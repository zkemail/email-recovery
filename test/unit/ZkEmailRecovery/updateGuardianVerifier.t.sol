// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";

contract ZkEmailRecovery_updateGuardianVerifier_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_UpdateGuardianVerifier_RevertWhen_UnauthorizedAccountForGuardian() public {
        address guardian = guardian1;

        MockGroth16Verifier newVerifier = new MockGroth16Verifier();
        address newVerifierAddr = address(newVerifier);

        vm.expectRevert(IZkEmailRecovery.UnauthorizedAccountForGuardian.selector);
        zkEmailRecovery.updateGuardianVerifier(guardian, newVerifierAddr);
    }

    function test_UpdateGuardianVerifier_RevertWhen_RecoveryInProcess() public {
        address guardian = guardian1;

        MockGroth16Verifier newVerifier = new MockGroth16Verifier();
        address newVerifierAddr = address(newVerifier);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.updateGuardianVerifier(guardian, newVerifierAddr);
    }

    function test_UpdateGuardianVerifier_Succeeds() public {
        address guardian = guardian1;
        EmailAuth guardianEmailAuth = EmailAuth(guardian);

        MockGroth16Verifier newVerifier = new MockGroth16Verifier();
        address newVerifierAddr = address(newVerifier);

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress, guardians, guardianWeights, threshold, delay, expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);

        address expectedVerifier = guardianEmailAuth.verifierAddr();
        assertEq(expectedVerifier, address(verifier));

        vm.startPrank(accountAddress);
        zkEmailRecovery.updateGuardianVerifier(guardian, newVerifierAddr);

        expectedVerifier = guardianEmailAuth.verifierAddr();
        assertEq(expectedVerifier, newVerifierAddr);
    }
}
