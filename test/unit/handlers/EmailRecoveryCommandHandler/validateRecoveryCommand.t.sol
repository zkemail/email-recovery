// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";

contract EmailRecoveryCommandHandler_validateRecoveryCommand_Test is UnitBase {
    using Strings for uint256;

    EmailRecoveryCommandHandler public emailRecoveryCommandHandler;
    string public recoveryDataHashString;
    bytes[] public commandParams;

    function setUp() public override {
        super.setUp();
        emailRecoveryCommandHandler = new EmailRecoveryCommandHandler();
        recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        commandParams = new bytes[](2);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(recoveryDataHashString);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        emailRecoveryCommandHandler.validateRecoveryCommand(invalidTemplateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_NoCommandParams() public {
        bytes[] memory emptyCommandParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidCommandParams.selector,
                emptyCommandParams.length,
                2
            )
        );
        emailRecoveryCommandHandler.validateRecoveryCommand(templateIdx, emptyCommandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_TooManyCommandParams() public {
        bytes[] memory longCommandParams = new bytes[](3);
        longCommandParams[0] = abi.encode(accountAddress1);
        longCommandParams[1] = abi.encode(recoveryDataHashString);
        longCommandParams[2] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                EmailRecoveryCommandHandler.InvalidCommandParams.selector,
                longCommandParams.length,
                2
            )
        );
        emailRecoveryCommandHandler.validateRecoveryCommand(templateIdx, longCommandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidAccount() public {
        commandParams[0] = abi.encode(address(0));

        vm.expectRevert(EmailRecoveryCommandHandler.InvalidAccount.selector);
        emailRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_ZeroRecoveryDataHash() public {
        commandParams[1] = abi.encode(bytes32(0));

        vm.expectRevert("invalid hex prefix");
        emailRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidHashLength() public {
        commandParams[1] = abi.encode(uint256(recoveryDataHash).toHexString(33));

        vm.expectRevert("bytes length is not 32");
        emailRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_Succeeds() public view {
        address accountFromEmail =
            emailRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
        assertEq(accountFromEmail, accountAddress1);
    }
}
