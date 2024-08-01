// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { UnitBase } from "../../UnitBase.t.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract EmailRecoveryUniversalFactory_deployUniversalEmailRecoveryModule_Test is UnitBase {
    function setUp() public override {
        super.setUp();
    }

    function test_DeployUniversalEmailRecoveryModule_Succeeds() public {
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes32 subjectHandlerSalt = bytes32(uint256(0));

        bytes memory subjectHandlerBytecode = type(EmailRecoverySubjectHandler).creationCode;
        address expectedSubjectHandler = Create2.computeAddress(
            subjectHandlerSalt,
            keccak256(subjectHandlerBytecode),
            address(emailRecoveryUniversalFactory)
        );

        bytes memory recoveryModuleBytecode = abi.encodePacked(
            type(UniversalEmailRecoveryModule).creationCode,
            abi.encode(
                address(verifier),
                address(dkimRegistry),
                address(emailAuthImpl),
                expectedSubjectHandler
            )
        );
        address expectedModule = Create2.computeAddress(
            recoveryModuleSalt,
            keccak256(recoveryModuleBytecode),
            address(emailRecoveryUniversalFactory)
        );

        vm.expectEmit();
        emit EmailRecoveryUniversalFactory.UniversalEmailRecoveryModuleDeployed(
            expectedModule, expectedSubjectHandler
        );
        (address emailRecoveryModule, address subjectHandler) = emailRecoveryUniversalFactory
            .deployUniversalEmailRecoveryModule(
            subjectHandlerSalt, recoveryModuleSalt, subjectHandlerBytecode, address(dkimRegistry)
        );

        assertEq(emailRecoveryModule, expectedModule);
        assertEq(subjectHandler, expectedSubjectHandler);
    }
}
