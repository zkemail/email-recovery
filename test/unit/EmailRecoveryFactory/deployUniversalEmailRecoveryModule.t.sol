// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { EmailRecoveryFactory } from "src/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/EmailRecoveryUniversalFactory.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";

contract EmailRecoveryFactory_deployUniversalEmailRecoveryModule_Test is UnitBase {
    function setUp() public override {
        super.setUp();
        emailRecoveryUniversalFactory =
            new EmailRecoveryUniversalFactory(address(verifier), address(emailAuthImpl));
    }

    function test_DeployUniversalEmailRecoveryModule_Succeeds() public {
        bytes32 recoveryManagerSalt = bytes32(uint256(0));
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes32 subjectHandlerSalt = bytes32(uint256(0));

        bytes memory subjectHandlerBytecode = type(EmailRecoverySubjectHandler).creationCode;
        address expectedSubjectHandler = Create2.computeAddress(
            subjectHandlerSalt,
            keccak256(subjectHandlerBytecode),
            address(emailRecoveryUniversalFactory)
        );

        bytes memory recoveryManagerBytecode = abi.encodePacked(
            type(EmailRecoveryManager).creationCode,
            abi.encode(
                address(verifier),
                address(dkimRegistry),
                address(emailAuthImpl),
                expectedSubjectHandler
            )
        );
        address expectedManager = Create2.computeAddress(
            recoveryManagerSalt,
            keccak256(recoveryManagerBytecode),
            address(emailRecoveryUniversalFactory)
        );

        bytes memory recoveryModuleBytecode = abi.encodePacked(
            type(UniversalEmailRecoveryModule).creationCode, abi.encode(expectedManager)
        );
        address expectedModule = Create2.computeAddress(
            recoveryModuleSalt,
            keccak256(recoveryModuleBytecode),
            address(emailRecoveryUniversalFactory)
        );

        (address emailRecoveryModule, address emailRecoveryManager, address subjectHandler) =
        emailRecoveryUniversalFactory.deployUniversalEmailRecoveryModule(
            subjectHandlerSalt,
            recoveryManagerSalt,
            recoveryModuleSalt,
            subjectHandlerBytecode,
            address(dkimRegistry)
        );

        assertEq(emailRecoveryManager, expectedManager);
        assertEq(emailRecoveryModule, expectedModule);
        assertEq(subjectHandler, expectedSubjectHandler);
    }
}
