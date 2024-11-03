// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract AccountHidingRecoveryCommandHandler_parseRecoveryDataHash_Test is UnitBase {
    using Strings for uint256;

    AccountHidingRecoveryCommandHandler public accountHidingRecoveryCommandHandler;
    string public accountHashString;
    string public recoveryDataHashString;
    bytes[] public commandParams;

    function setUp() public override {
        super.setUp();
        accountHidingRecoveryCommandHandler = new AccountHidingRecoveryCommandHandler();

        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));
        accountHashString = uint256(accountHash).toHexString(32);
        recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountHashString);
        commandParams[1] = abi.encode(recoveryDataHashString);
    }

    function test_ParseRecoveryDataHash_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.InvalidTemplateIndex.selector,
                invalidTemplateIdx,
                0
            )
        );
        accountHidingRecoveryCommandHandler.parseRecoveryDataHash(invalidTemplateIdx, commandParams);
    }

    function test_ParseRecoveryDataHash_Succeeds() public view {
        bytes32 expectedRecoveryDataHash = keccak256(recoveryData);

        bytes32 _recoveryDataHash =
            accountHidingRecoveryCommandHandler.parseRecoveryDataHash(templateIdx, commandParams);

        assertEq(_recoveryDataHash, expectedRecoveryDataHash);
    }
}
