// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";
import { UnitBase } from "../UnitBase.t.sol";
import { EmailRecoveryFactory } from "src/EmailRecoveryFactory.sol";
import { EmailRecoverySubjectHandler } from "src/handlers/EmailRecoverySubjectHandler.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";

contract EmailRecoveryFactory_deployAll_Test is UnitBase {
    function setUp() public override {
        super.setUp();
        emailRecoveryFactory = new EmailRecoveryFactory();
    }

    function test_DeployAll_Succeeds() public {
        bytes32 recoveryManagerSalt = bytes32(uint256(0));
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes32 subjectHandlerSalt = bytes32(uint256(0));

        bytes memory subjectHandlerBytecode = type(EmailRecoverySubjectHandler).creationCode;
        address expectedSubjectHandler = Create2.computeAddress(
            subjectHandlerSalt, keccak256(subjectHandlerBytecode), address(emailRecoveryFactory)
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
            recoveryManagerSalt, keccak256(recoveryManagerBytecode), address(emailRecoveryFactory)
        );

        bytes memory recoveryModuleBytecode = abi.encodePacked(
            type(EmailRecoveryModule).creationCode,
            abi.encode(expectedManager, validatorAddress, functionSelector)
        );
        address expectedModule = Create2.computeAddress(
            recoveryModuleSalt, keccak256(recoveryModuleBytecode), address(emailRecoveryFactory)
        );

        (address emailRecoveryManager, address emailRecoveryModule, address subjectHandler) =
        emailRecoveryFactory.deployAll(
            subjectHandlerSalt,
            recoveryManagerSalt,
            recoveryModuleSalt,
            subjectHandlerBytecode,
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            validatorAddress,
            functionSelector
        );

        assertEq(emailRecoveryManager, expectedManager);
        assertEq(emailRecoveryModule, expectedModule);
        assertEq(subjectHandler, expectedSubjectHandler);
    }
}
