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
import { EmailRecoveryModuleHarness } from "../../EmailRecoveryModuleHarness.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";

abstract contract EmailRecoveryModuleBase is BaseTest {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    EmailRecoveryFactory public emailRecoveryFactory;
    address public commandHandlerAddress;
    EmailRecoveryModuleHarness public emailRecoveryModule;

    address public emailRecoveryModuleAddress;

    function setUp() public virtual override {
        super.setUp();

        // create owners
        address[] memory owners = new address[](1);
        owners[0] = owner1;

        // Install modules
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1)
        });
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry)
        });
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
        bytes32 commandHandlerSalt = bytes32(uint256(0));
        commandHandlerAddress = Create2.deploy(0, commandHandlerSalt, handlerBytecode);

        emailRecoveryModule = new EmailRecoveryModuleHarness(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer,
            validatorAddress,
            functionSelector
        );
        emailRecoveryModuleAddress = address(emailRecoveryModule);

        // 0- verify that existing tests have failed
        // (Expect 15 tests to fail under this condition.)

        // // 1- verify that setting the transaction initiator flag to true works as expected.
        // vm.startPrank(killSwitchAuthorizer);
        // emailRecoveryModule.setTransactionInitiator(address(this), true);
        // vm.stopPrank();

        // // 2- confirm that the functionality works correctly after 6 months has passed.
        // vm.warp(block.timestamp + 15_768_000); // 6 months

        // // 3- test the scenario where the transaction initiator flag is initially set to true, then changed to false.
        // // (Expect 15 tests to fail under this condition.)
        // vm.startPrank(killSwitchAuthorizer);
        // emailRecoveryModule.setTransactionInitiator(address(this), false);
        // vm.stopPrank();

        // // 4- validate the behavior when the transaction initiator flag is set to true first, then changed to false,
        // // and the contract is working after a waiting period of 6 months.
        // vm.startPrank(killSwitchAuthorizer);
        // emailRecoveryModule.setTransactionInitiator(address(this), true);
        // emailRecoveryModule.setTransactionInitiator(address(this), false);
        // vm.stopPrank();
        // vm.warp(block.timestamp + 15_768_000); // 6 months

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress1
            );
        }
    }

    function setRecoveryData() public override {
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        recoveryCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        recoveryData = abi.encode(validatorAddress, recoveryCalldata);
        recoveryDataHash = keccak256(recoveryData);
    }
}
