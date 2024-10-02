// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoveryCommandHandler_validateAcceptanceCommand_Test is SafeUnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_ValidateAcceptanceCommand_RevertWhen_InvalidTemplateIndex() public {
        skipIfNotSafeAccountType();
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress1);
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoveryCommandHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        safeRecoveryCommandHandler.validateAcceptanceCommand(invalidTemplateIdx, commandParams);
    }

    function test_ValidateAcceptanceCommand_RevertWhen_NoCommandParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory emptyCommandParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoveryCommandHandler.InvalidCommandParams.selector,
                emptyCommandParams.length,
                1
            )
        );
        safeRecoveryCommandHandler.validateAcceptanceCommand(templateIdx, emptyCommandParams);
    }

    function test_ValidateAcceptanceCommand_RevertWhen_TooManyCommandParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoveryCommandHandler.InvalidCommandParams.selector, commandParams.length, 1
            )
        );
        safeRecoveryCommandHandler.validateAcceptanceCommand(templateIdx, commandParams);
    }

    function test_ValidateAcceptanceCommand_Succeeds() public {
        skipIfNotSafeAccountType();
        bytes[] memory commandParams = new bytes[](1);
        commandParams[0] = abi.encode(accountAddress1);

        address account =
            safeRecoveryCommandHandler.validateAcceptanceCommand(templateIdx, commandParams);
        assertEq(account, accountAddress1);
    }
}
