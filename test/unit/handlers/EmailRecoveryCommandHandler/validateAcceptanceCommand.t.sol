// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

contract EmailRecoveryCommandHandler_validateAcceptanceCommand_Test is UnitBase {
    EmailRecoveryCommandHandler public emailRecoveryCommandHandler;

    function setUp() public override {
        super.setUp();
        emailRecoveryCommandHandler = new EmailRecoveryCommandHandler();
    }

    function test_ValidateAcceptanceCommand_RevertWhen_InvalidTemplateIndex() public {
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress1);
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        emailRecoveryCommandHandler.validateAcceptanceCommand(invalidTemplateIdx, commandParams);
    }

    function test_ValidateAcceptanceCommand_RevertWhen_NoCommandParams() public {
        bytes[] memory emptyCommandParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidCommandParams.selector,
                emptyCommandParams.length,
                1
            )
        );
        emailRecoveryCommandHandler.validateAcceptanceCommand(templateIdx, emptyCommandParams);
    }

    function test_ValidateAcceptanceCommand_RevertWhen_TooManyCommandParams() public {
        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidCommandParams.selector, commandParams.length, 1
            )
        );
        emailRecoveryCommandHandler.validateAcceptanceCommand(templateIdx, commandParams);
    }

    function test_ValidateAcceptanceCommand_Succeeds() public view {
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress1);

        address account =
            emailRecoveryCommandHandler.validateAcceptanceCommand(templateIdx, commandParams);
        assertEq(account, accountAddress1);
    }
}
