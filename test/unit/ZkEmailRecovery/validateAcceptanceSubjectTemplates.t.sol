// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/console2.sol";
import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

import { IZkEmailRecovery } from "src/interfaces/IZkEmailRecovery.sol";
import { OwnableValidatorRecoveryModule } from "src/modules/OwnableValidatorRecoveryModule.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { GuardianStorage, GuardianStatus } from "src/libraries/EnumerableGuardianMap.sol";
import { UnitBase } from "../UnitBase.t.sol";

contract ZkEmailRecovery_validateAcceptanceSubjectTemplates_Test is UnitBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    OwnableValidatorRecoveryModule recoveryModule;
    address recoveryModuleAddress;

    function setUp() public override {
        super.setUp();

        recoveryModule =
            new OwnableValidatorRecoveryModule{ salt: "test salt" }(address(zkEmailRecovery));
        recoveryModuleAddress = address(recoveryModule);
    }

    function test_ValidateAcceptanceSubjectTemplates_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);

        vm.expectRevert(IZkEmailRecovery.InvalidTemplateIndex.selector);
        zkEmailRecovery.exposed_validateAcceptanceSubjectTemplates(
            invalidTemplateIdx, subjectParams
        );
    }

    function test_ValidateAcceptanceSubjectTemplates_RevertWhen_NoSubjectParams() public {
        bytes[] memory emptySubjectParams;

        vm.expectRevert(IZkEmailRecovery.InvalidSubjectParams.selector);
        zkEmailRecovery.exposed_validateAcceptanceSubjectTemplates(templateIdx, emptySubjectParams);
    }

    function test_ValidateAcceptanceSubjectTemplates_RevertWhen_TooManySubjectParams() public {
        bytes[] memory subjectParams = new bytes[](2);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode("extra param");

        vm.expectRevert(IZkEmailRecovery.InvalidSubjectParams.selector);
        zkEmailRecovery.exposed_validateAcceptanceSubjectTemplates(templateIdx, subjectParams);
    }

    function test_ValidateAcceptanceSubjectTemplates_Succeeds() public view {
        bytes[] memory subjectParams = new bytes[](1);
        subjectParams[0] = abi.encode(accountAddress);

        address account =
            zkEmailRecovery.exposed_validateAcceptanceSubjectTemplates(templateIdx, subjectParams);
        assertEq(account, accountAddress);
    }
}
