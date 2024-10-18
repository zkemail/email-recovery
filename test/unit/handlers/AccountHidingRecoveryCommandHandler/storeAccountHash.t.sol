// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";

contract AccountHidingRecoveryCommandHandler_storeAccountHash_Test is UnitBase {
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

    function test_StoreAccountHash_RevertWhen_ExistingStoredAccountHash() public {
        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AccountHidingRecoveryCommandHandler.ExistingStoredAccountHash.selector,
                accountAddress1
            )
        );
        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);
    }

    function test_StoreAccountHash_StoresZeroAccountHash() public {
        address zeroAddress = address(0);
        bytes32 accountHash = keccak256(abi.encodePacked(zeroAddress));

        accountHidingRecoveryCommandHandler.storeAccountHash(zeroAddress);

        address storedAccount = accountHidingRecoveryCommandHandler.accountHashes(accountHash);
        assertEq(zeroAddress, storedAccount);
    }

    function test_StoreAccountHash_DoesNotFindAccountForNonPackedEncodedAddress() public {
        bytes32 accountHash = keccak256(abi.encode(accountAddress1));

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        address storedAccount = accountHidingRecoveryCommandHandler.accountHashes(accountHash);
        assertEq(address(0), storedAccount);
    }

    function test_StoreAccountHash_Succeeds() public {
        bytes32 accountHash = keccak256(abi.encodePacked(accountAddress1));

        accountHidingRecoveryCommandHandler.storeAccountHash(accountAddress1);

        address storedAccount = accountHidingRecoveryCommandHandler.accountHashes(accountHash);
        assertEq(accountAddress1, storedAccount);
    }
}
