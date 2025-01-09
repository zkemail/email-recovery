// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

import { BaseTest, CommandHandlerType } from "test/Base.t.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModuleHarness } from "./UniversalEmailRecoveryModuleHarness.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";

/// @dev - This file is originally implemented in the EOA-TX-builder module.
import { IVerifier, EoaProof } from "../src/interfaces/circuits/IVerifier.sol";


abstract contract UnitBase is BaseTest {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    EoaProof memory proof;            /// @dev - This parameter for passing the IVerifier# verifyEoaProof()
    uint256[34] calldata pubSignals;  /// @dev - This parameter for passing the IVerifier# verifyEoaProof()

    EmailRecoveryFactory public emailRecoveryFactory;
    EmailRecoveryUniversalFactory public emailRecoveryUniversalFactory;
    address public commandHandlerAddress;
    UniversalEmailRecoveryModuleHarness public emailRecoveryModule;

    address public emailRecoveryModuleAddress;

    function setUp() public virtual override {
        super.setUp();

        // Install modules
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1)
        });

        //
        if (isAccountTypeSafe()) {
            validatorAddress = accountAddress1;
        }

        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(
                validatorAddress,
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });

        /// @dev - [TODO]: Set the values for passing the IVerifier# verifyEoaProof()
        proof = _proof;
        pubSignals = _pubSignals;
    }

    // Helper functions

    function computeEmailAuthAddress(
        address account,
        bytes32 accountSalt
    )
        public
        view
        override
        returns (address)
    {
        return emailRecoveryModule.computeEmailAuthAddress(account, accountSalt);
    }

    function deployModule(bytes memory handlerBytecode) public override {
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));
        emailRecoveryUniversalFactory =
            new EmailRecoveryUniversalFactory(address(verifier), address(emailAuthImpl));

        bytes32 commandHandlerSalt = bytes32(uint256(0));
        commandHandlerAddress = Create2.deploy(0, commandHandlerSalt, handlerBytecode);

        emailRecoveryModule = new UniversalEmailRecoveryModuleHarness(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer
        );
        emailRecoveryModuleAddress = address(emailRecoveryModule);

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress1
            );
        }
    }

    function setRecoveryData() public override {
        if (isAccountTypeSafe()) {
            functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));
            recoveryCalldata =
                abi.encodeWithSelector(functionSelector, address(1), owner1, newOwner1);
            recoveryData = abi.encode(accountAddress1, recoveryCalldata);
            recoveryDataHash = keccak256(recoveryData);
        } else {
            functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
            recoveryCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
            recoveryData = abi.encode(validatorAddress, recoveryCalldata);
            recoveryDataHash = keccak256(recoveryData);
        }
    }
}
