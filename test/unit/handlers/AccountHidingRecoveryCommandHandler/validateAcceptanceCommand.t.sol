// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract AccountHidingRecoveryCommandHandler_validateAcceptanceCommand_Test is UnitBase {
    using Strings for uint256;

    AccountHidingRecoveryCommandHandler public accountHidingRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        accountHidingRecoveryCommandHandler = new AccountHidingRecoveryCommandHandler();
    }

    function test_ValidateAcceptanceCommand_RevertWhen_InvalidTemplateIndex() public {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));
        string memory accountHashString = uint256(accountHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountHashString);
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.InvalidTemplateIndex.selector,
                invalidTemplateIdx,
                0
            )
        );
        accountHidingRecoveryCommandHandler.validateAcceptanceCommand(
            invalidTemplateIdx, commandParams
        );
    }

    function test_ValidateAcceptanceCommand_RevertWhen_NoCommandParams() public {
        bytes[] memory emptyCommandParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.InvalidCommandParams.selector,
                emptyCommandParams.length,
                1
            )
        );
        accountHidingRecoveryCommandHandler.validateAcceptanceCommand(
            templateIdx, emptyCommandParams
        );
    }

    function test_ValidateAcceptanceCommand_RevertWhen_TooManyCommandParams() public {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));
        string memory accountHashString = uint256(accountHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountHashString);
        commandParams[1] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.InvalidCommandParams.selector,
                commandParams.length,
                1
            )
        );
        accountHidingRecoveryCommandHandler.validateAcceptanceCommand(templateIdx, commandParams);
    }

    function test_ValidateAcceptanceCommand_Succeeds() public {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));
        string memory accountHashString = uint256(accountHash).toHexString(32);

        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountHashString);

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        address account = accountHidingRecoveryCommandHandler.validateAcceptanceCommand(
            templateIdx, commandParams
        );
        assertEq(account, accountAddress1);
    }
}
