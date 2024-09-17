// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

contract EmailRecoveryFactory_deployAll_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_DeployEmailRecoveryModule_Succeeds() public {
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes32 commandHandlerSalt = bytes32(uint256(0));

        bytes memory commandHandlerBytecode = type(EmailRecoveryCommandHandler).creationCode;
        address expectedCommandHandler = Create2.computeAddress(
            commandHandlerSalt, keccak256(commandHandlerBytecode), address(emailRecoveryFactory)
        );

        bytes memory recoveryModuleBytecode = abi.encodePacked(
            type(EmailRecoveryModule).creationCode,
            abi.encode(
                address(verifier),
                address(dkimRegistry),
                address(emailAuthImpl),
                expectedCommandHandler,
                validatorAddress,
                functionSelector
            )
        );
        address expectedModule = Create2.computeAddress(
            recoveryModuleSalt, keccak256(recoveryModuleBytecode), address(emailRecoveryFactory)
        );

        vm.expectEmit();
        emit EmailRecoveryFactory.EmailRecoveryModuleDeployed(
            expectedModule, expectedCommandHandler, validatorAddress, functionSelector
        );
        (address emailRecoveryModule, address commandHandler) = emailRecoveryFactory
            .deployEmailRecoveryModule(
            commandHandlerSalt,
            recoveryModuleSalt,
            commandHandlerBytecode,
            address(dkimRegistry),
            validatorAddress,
            functionSelector
        );

        assertEq(emailRecoveryModule, expectedModule);
        assertEq(commandHandler, expectedCommandHandler);
    }
}
