// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { SafeUnitBase } from "../../SafeUnitBase.t.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";

contract SafeRecoveryCommandHandler_parseRecoveryDataHash_Test is SafeUnitBase {
    bytes[] commandParams;

    function setUp() public override {
        super.setUp();

        commandParams = new bytes[](3);
        commandParams[0] = abi.encode(accountAddress1);
        commandParams[1] = abi.encode(owner1);
        commandParams[2] = abi.encode(newOwner1);
    }

    function test_ParseRecoveryDataHash_RevertWhen_InvalidTemplateIndex() public {
        skipIfNotSafeAccountType();

        uint256 invalidTemplateIdx = 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeRecoveryCommandHandler.InvalidTemplateIndex.selector, invalidTemplateIdx, 0
            )
        );
        safeRecoveryCommandHandler.parseRecoveryDataHash(invalidTemplateIdx, commandParams);
    }

    function test_ParseRecoveryDataHash_Succeeds() public {
        skipIfNotSafeAccountType();

        bytes32 actualRecoveryDataHash =
            safeRecoveryCommandHandler.parseRecoveryDataHash(templateIdx, commandParams);

        assertEq(actualRecoveryDataHash, recoveryDataHash);
    }
}
