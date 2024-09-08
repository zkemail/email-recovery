// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";

contract SafeRecoveryCommandHandler_validateRecoveryCommand_Test is SafeUnitBase {
    using Strings for uint256;

    bytes[] commandParams;

    function setUp() public override {
        super.setUp();

        commandParams = new bytes[](3);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(owner1);
        commandParams[2] = abi.encode(newOwner1);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidTemplateIndex() public {
        skipIfNotSafeAccountType();
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoveryCommandHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        safeRecoveryCommandHandler.validateRecoveryCommand(invalidTemplateIdx, commandParams);
    }

    function test_ValidateAcceptanceCommand_RevertWhen_NoCommandParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory emptyCommandParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoveryCommandHandler.InvalidCommandParams.selector,
                emptyCommandParams.length,
                3
            )
        );
        safeRecoveryCommandHandler.validateRecoveryCommand(templateIdx, emptyCommandParams);
    }

    function test_ValidateAcceptanceCommand_RevertWhen_TooManyCommandParams() public {
        skipIfNotSafeAccountType();
        bytes[] memory longCommandParams = new bytes[](4);
        longCommandParams[0] = commandParams[0];
        longCommandParams[1] = commandParams[1];
        longCommandParams[2] = commandParams[2];
        longCommandParams[3] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoveryCommandHandler.InvalidCommandParams.selector,
                longCommandParams.length,
                3
            )
        );
        safeRecoveryCommandHandler.validateRecoveryCommand(templateIdx, longCommandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidOldOwner() public {
        skipIfNotSafeAccountType();
        commandParams[1] = abi.encode(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(SafeRecoveryCommandHandler.InvalidOldOwner.selector, address(0))
        );
        safeRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_ZeroNewOwner() public {
        skipIfNotSafeAccountType();
        commandParams[2] = abi.encode(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(SafeRecoveryCommandHandler.InvalidNewOwner.selector, address(0))
        );
        safeRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidNewOwner() public {
        skipIfNotSafeAccountType();
        commandParams[2] = abi.encode(owner1);

        vm.expectRevert(
            abi.encodeWithSelector(SafeRecoveryCommandHandler.InvalidNewOwner.selector, owner1)
        );
        safeRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_Succeeds() public {
        skipIfNotSafeAccountType();
        address accountFromEmail =
            safeRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
        assertEq(accountFromEmail, accountAddress1);
    }
}
