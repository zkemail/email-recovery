// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";

contract EmailRecoverySubjectHandler_parseRecoveryCalldataHash_Test is UnitBase {
    using Strings for uint256;

    string calldataHashString;
    bytes[] subjectParams;

    function setUp() public override {
        super.setUp();

        calldataHashString = uint256(calldataHash).toHexString(32);

        subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(recoveryModuleAddress);
        subjectParams[2] = abi.encode(calldataHashString);
    }

    function test_ParseRecoveryCalldataHash_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoverySubjectHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        emailRecoveryHandler.parseRecoveryCalldataHash(invalidTemplateIdx, subjectParams);
    }

    function test_ParseRecoveryCalldataHash_Succeeds() public {
        bytes32 expectedCalldataHash = keccak256(recoveryCalldata);

        bytes32 calldataHash =
            emailRecoveryHandler.parseRecoveryCalldataHash(templateIdx, subjectParams);

        assertEq(calldataHash, expectedCalldataHash);
    }
}
