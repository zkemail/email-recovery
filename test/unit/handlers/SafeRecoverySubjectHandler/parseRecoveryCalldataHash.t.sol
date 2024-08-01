// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";
import { SafeRecoverySubjectHandler } from "src/handlers/SafeRecoverySubjectHandler.sol";

contract SafeRecoverySubjectHandler_parseRecoveryCalldataHash_Test is SafeUnitBase {
    bytes[] subjectParams;

    function setUp() public override {
        super.setUp();

        subjectParams = new bytes[](4);
        subjectParams[0] = abi.encode(accountAddress1);
        subjectParams[1] = abi.encode(owner1);
        subjectParams[2] = abi.encode(newOwner1);
        subjectParams[3] = abi.encode(recoveryModuleAddress);
    }

    function test_ParseRecoveryCalldataHash_RevertWhen_InvalidTemplateIndex() public {
        skipIfNotSafeAccountType();

        uint256 invalidTemplateIdx = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoverySubjectHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        safeRecoverySubjectHandler.parseRecoveryCalldataHash(invalidTemplateIdx, subjectParams);
    }

    function test_ParseRecoveryCalldataHash_Succeeds() public {
        skipIfNotSafeAccountType();

        bytes32 actualCalldataHash =
            safeRecoverySubjectHandler.parseRecoveryCalldataHash(templateIdx, subjectParams);

        assertEq(actualCalldataHash, calldataHash);
    }
}
