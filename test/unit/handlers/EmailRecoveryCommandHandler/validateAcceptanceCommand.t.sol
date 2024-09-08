// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UnitBase } from "../../UnitBase.t.sol";

contract EmailRecoveryCommandHandler_validateAcceptanceCommand_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ValidateAcceptanceCommand_RevertWhen_InvalidTemplateIndex() public {
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress);
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        emailRecoveryHandler.validateAcceptanceCommand(invalidTemplateIdx, commandParams);
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
        emailRecoveryHandler.validateAcceptanceCommand(templateIdx, emptyCommandParams);
    }

    function test_ValidateAcceptanceCommand_RevertWhen_TooManyCommandParams() public {
        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountAddress);
        commandParams[1] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidCommandParams.selector, commandParams.length, 1
            )
        );
        emailRecoveryHandler.validateAcceptanceCommand(templateIdx, commandParams);
    }

    function test_ValidateAcceptanceCommand_Succeeds() public view {
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress);

        address account = emailRecoveryHandler.validateAcceptanceCommand(templateIdx, commandParams);
        assertEq(account, accountAddress);
    }
}
