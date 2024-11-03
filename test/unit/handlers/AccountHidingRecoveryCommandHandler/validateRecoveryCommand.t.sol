// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract AccountHidingRecoveryCommandHandler_validateRecoveryCommand_Test is UnitBase {
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

    function test_ValidateRecoveryCommand_RevertWhen_InvalidTemplateIndex() public {
        uint256 invalidTemplateIdx = 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.InvalidTemplateIndex.selector,
                invalidTemplateIdx,
                0
            )
        );
        accountHidingRecoveryCommandHandler.validateRecoveryCommand(
            invalidTemplateIdx, commandParams
        );
    }

    function test_ValidateRecoveryCommand_RevertWhen_NoCommandParams() public {
        bytes[] memory emptyCommandParams;

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.InvalidCommandParams.selector,
                emptyCommandParams.length,
                2
            )
        );
        accountHidingRecoveryCommandHandler.validateRecoveryCommand(templateIdx, emptyCommandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_TooManyCommandParams() public {
        bytes[] memory longCommandParams = new bytes[](3);
        longCommandParams[0] = abi.encode(accountHashString);
        longCommandParams[1] = abi.encode(recoveryDataHashString);
        longCommandParams[2] = abi.encode("extra param");

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.InvalidCommandParams.selector,
                longCommandParams.length,
                2
            )
        );
        accountHidingRecoveryCommandHandler.validateRecoveryCommand(templateIdx, longCommandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidAccount() public {
        bytes32 zeroAccountHash = keccak256(abi.encodePacked(address(0)));
        string memory zeroAccountHashString = uint256(zeroAccountHash).toHexString(32);
        commandParams[0] = abi.encode(zeroAccountHashString);

        vm.expectRevert(AccountHidingRecoveryCommandHandler.InvalidAccount.selector);
        accountHidingRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_ZeroRecoveryDataHash() public {
        commandParams[1] = abi.encode(bytes32(0));

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        vm.expectRevert("invalid hex prefix");
        accountHidingRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_RevertWhen_InvalidHashLength() public {
        commandParams[1] = abi.encode(uint256(recoveryDataHash).toHexString(33));

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        vm.expectRevert("bytes length is not 32");
        accountHidingRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
    }

    function test_ValidateRecoveryCommand_Succeeds() public {
        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);
        address accountFromEmail =
            accountHidingRecoveryCommandHandler.validateRecoveryCommand(templateIdx, commandParams);
        assertEq(accountFromEmail, accountAddress1);
    }
}
