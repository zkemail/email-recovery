// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoverySubjectHandler_extractRecoveredAccountFromRecoverySubject_Test is UnitBase {
    using Strings for uint256;

    function setUp() public override {
        super.setUp();
    }

    function test_ExtractRecoveredAccountFromRecoverySubject_Succeeds() public view {
        string memory calldataHashString = uint256(calldataHash).toHexString(32);

        bytes[] memory subjectParams = new bytes[](3);
        subjectParams[0] = abi.encode(accountAddress);
        subjectParams[1] = abi.encode(recoveryModuleAddress);
        subjectParams[2] = abi.encode(calldataHashString);

        address extractedAccount = emailRecoveryHandler.extractRecoveredAccountFromRecoverySubject(
            subjectParams, templateIdx
        );
        assertEq(extractedAccount, accountAddress);
    }
}
