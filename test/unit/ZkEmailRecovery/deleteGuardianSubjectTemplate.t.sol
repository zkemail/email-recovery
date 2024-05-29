// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import {EmailAuth} from "ether-email-auth/packages/contracts/src/EmailAuth.sol";

import {UnitBase} from "../UnitBase.t.sol";
import {IZkEmailRecovery} from "src/interfaces/IZkEmailRecovery.sol";
import {OwnableValidatorRecoveryModule} from "src/modules/OwnableValidatorRecoveryModule.sol";

contract ZkEmailRecovery_deleteGuardianSubjectTemplate_Test is UnitBase {
    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule = new OwnableValidatorRecoveryModule{salt: "test salt"}(
            address(zkEmailRecovery)
        );
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_DeleteGuardianSubjectTemplate_RevertWhen_UnauthorizedAccountForGuardian()
        public
    {
        address guardian = guardian1;
        uint templateId = 0;

        vm.expectRevert(
            IZkEmailRecovery.UnauthorizedAccountForGuardian.selector
        );
        zkEmailRecovery.deleteGuardianSubjectTemplate(guardian, templateId);
    }

    function test_DeleteGuardianSubjectTemplate_RevertWhen_RecoveryInProcess()
        public
    {
        address guardian = guardian1;
        uint templateId = 0;

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();

        acceptGuardian(accountSalt1);
        vm.warp(12 seconds);
        handleRecovery(recoveryModuleAddress, accountSalt1);

        vm.startPrank(accountAddress);
        vm.expectRevert(IZkEmailRecovery.RecoveryInProcess.selector);
        zkEmailRecovery.deleteGuardianSubjectTemplate(guardian, templateId);
    }

    function test_DeleteGuardianSubjectTemplate_DeleteAcceptanceSubjectTemplates()
        public
    {
        address guardian = guardian1;
        EmailAuth guardianEmailAuth = EmailAuth(guardian);

        uint256 expectedTemplateLength = zkEmailRecovery
        .acceptanceSubjectTemplates()[0].length;

        uint256 templateId = zkEmailRecovery.computeAcceptanceTemplateId(
            templateIdx
        );

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();
        acceptGuardian(accountSalt1);

        string[] memory subjectTemplate = guardianEmailAuth.getSubjectTemplate(
            templateId
        );
        assertEq(subjectTemplate.length, expectedTemplateLength);

        vm.startPrank(accountAddress);
        zkEmailRecovery.deleteGuardianSubjectTemplate(guardian, templateId);
        vm.stopPrank();

        vm.expectRevert("template id not exists");
        subjectTemplate = guardianEmailAuth.getSubjectTemplate(templateId);
    }

    function test_DeleteGuardianSubjectTemplate_DeleteRecoverySubjectTemplates()
        public
    {
        address guardian = guardian1;
        EmailAuth guardianEmailAuth = EmailAuth(guardian);

        uint256 expectedTemplateLength = zkEmailRecovery
        .recoverySubjectTemplates()[0].length;

        uint256 templateId = zkEmailRecovery.computeRecoveryTemplateId(
            templateIdx
        );

        vm.startPrank(accountAddress);
        zkEmailRecovery.configureRecovery(
            recoveryModuleAddress,
            guardians,
            guardianWeights,
            threshold,
            delay,
            expiry
        );
        vm.stopPrank();
        acceptGuardian(accountSalt1);

        string[] memory subjectTemplate = guardianEmailAuth.getSubjectTemplate(
            templateId
        );
        assertEq(subjectTemplate.length, expectedTemplateLength);

        vm.startPrank(accountAddress);
        zkEmailRecovery.deleteGuardianSubjectTemplate(guardian, templateId);
        vm.stopPrank();

        vm.expectRevert("template id not exists");
        subjectTemplate = guardianEmailAuth.getSubjectTemplate(templateId);
    }
}
