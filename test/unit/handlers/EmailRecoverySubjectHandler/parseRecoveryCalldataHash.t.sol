// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";

contract EmailRecoverySubjectHandler_parseRecoveryDataHash_Test is UnitBase {
    using Strings for uint256;

    string recoveryDataHashString;
    bytes[] subjectParams;

    function setUp() public override {
        super.setUp();

        recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        subjectParams = new bytes[](2);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(recoveryDataHashString);
    }

    function test_ParseRecoveryDataHash_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        emailRecoveryHandler.parseRecoveryDataHash(invalidTemplateIdx, subjectParams);
    }

    function test_ParseRecoveryDataHash_Succeeds() public {
        bytes32 expectedRecoveryDataHash = keccak256(recoveryData);

        bytes32 recoveryDataHash =
            emailRecoveryHandler.parseRecoveryDataHash(templateIdx, subjectParams);

        assertEq(recoveryDataHash, expectedRecoveryDataHash);
    }
}
