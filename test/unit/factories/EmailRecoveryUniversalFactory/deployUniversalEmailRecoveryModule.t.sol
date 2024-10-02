// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract EmailRecoveryUniversalFactory_deployUniversalEmailRecoveryModule_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_DeployUniversalEmailRecoveryModule_Succeeds() public {
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes32 commandHandlerSalt = bytes32(uint256(0));

        bytes memory commandHandlerBytecode = type(EmailRecoveryCommandHandler).creationCode;
        address expectedCommandHandler = Create2.computeAddress(
            commandHandlerSalt,
            keccak256(commandHandlerBytecode),
            address(emailRecoveryUniversalFactory)
        );

        bytes memory recoveryModuleBytecode = abi.encodePacked(
            type(UniversalEmailRecoveryModule).creationCode,
            abi.encode(
                address(verifier),
                address(dkimRegistry),
                address(emailAuthImpl),
                expectedCommandHandler
            )
        );
        address expectedModule = Create2.computeAddress(
            recoveryModuleSalt,
            keccak256(recoveryModuleBytecode),
            address(emailRecoveryUniversalFactory)
        );

        vm.expectEmit();
        emit EmailRecoveryUniversalFactory.UniversalEmailRecoveryModuleDeployed(
            expectedModule, expectedCommandHandler
        );
        (address emailRecoveryModule, address commandHandler) = emailRecoveryUniversalFactory
            .deployUniversalEmailRecoveryModule(
            commandHandlerSalt, recoveryModuleSalt, commandHandlerBytecode, address(dkimRegistry)
        );

        assertEq(emailRecoveryModule, expectedModule);
        assertEq(commandHandler, expectedCommandHandler);
    }
}
