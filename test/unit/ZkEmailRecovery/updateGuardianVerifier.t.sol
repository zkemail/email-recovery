// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { EmailAuth } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import { UnitBase } from "../UnitBase.t.sol";
import { IEmailRecoveryManager } from "src/interfaces/IEmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";

contract ZkEmailRecovery_updateGuardianVerifier_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidator validator;
    EmailRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        validator = new OwnableValidator();
        recoveryModule = new EmailRecoveryModule{ salt: "test salt" }(address(emailRecoveryManager));
        recoveryModuleAddress = address(recoveryModule);

        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(owner, recoveryModuleAddress)
        });
        // Install recovery module - configureRecovery is called on `onInstall`
        instance.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
            data: abi.encode(address(validator), guardians, guardianWeights, threshold, delay, expiry)
        });
    }

    function test_UpdateGuardianVerifier_RevertWhen_UnauthorizedAccountForGuardian() public {
        address guardian = guardian1;

        MockGroth16Verifier newVerifier = new MockGroth16Verifier();
        address newVerifierAddr = address(newVerifier);

        vm.expectRevert(IEmailRecoveryManager.UnauthorizedAccountForGuardian.selector);
        emailRecoveryManager.updateGuardianVerifier(guardian, newVerifierAddr);
    }

    function test_UpdateGuardianVerifier_RevertWhen_RecoveryInProcess() public {
        address guardian = guardian1;

        MockGroth16Verifier newVerifier = new MockGroth16Verifier();
        address newVerifierAddr = address(newVerifier);

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IEmailRecoveryManager.RecoveryInProcess.selector);
        emailRecoveryManager.updateGuardianVerifier(guardian, newVerifierAddr);
    }

    function test_UpdateGuardianVerifier_Succeeds() public {
        address guardian = guardian1;
        EmailAuth guardianEmailAuth = EmailAuth(guardian);

        MockGroth16Verifier newVerifier = new MockGroth16Verifier();
        address newVerifierAddr = address(newVerifier);

        acceptGuardian(accountSalt1);

        address expectedVerifier = guardianEmailAuth.verifierAddr();
        assertEq(expectedVerifier, address(verifier));

        vm.startPrank(accountAddress);
        emailRecoveryManager.updateGuardianVerifier(guardian, newVerifierAddr);

        expectedVerifier = guardianEmailAuth.verifierAddr();
        assertEq(expectedVerifier, newVerifierAddr);
    }
}
