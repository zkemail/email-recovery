// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import {
    MODULE_TYPE_EXECUTOR,
    MODULE_TYPE_VALIDATOR
} from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { BaseTest, CommandHandlerType } from "../../../Base.t.sol";

abstract contract OwnableValidatorRecovery_EmailRecoveryModule_Base is BaseTest {
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    EmailRecoveryFactory public emailRecoveryFactory;
    address public commandHandlerAddress;
    EmailRecoveryModule public emailRecoveryModule;

    address public emailRecoveryModuleAddress;

    bytes public recoveryData1;
    bytes public recoveryData2;
    bytes public recoveryData3;
    bytes32 public recoveryDataHash1;
    bytes32 public recoveryDataHash2;
    bytes32 public recoveryDataHash3;

    function setUp() public virtual override {
        super.setUp();

        bytes memory changeOwnerCalldata1 = abi.encodeWithSelector(functionSelector, newOwner1);
        bytes memory changeOwnerCalldata2 = abi.encodeWithSelector(functionSelector, newOwner2);
        bytes memory changeOwnerCalldata3 = abi.encodeWithSelector(functionSelector, newOwner3);
        recoveryData1 = abi.encode(validatorAddress, changeOwnerCalldata1);
        recoveryData2 = abi.encode(validatorAddress, changeOwnerCalldata2);
        recoveryData3 = abi.encode(validatorAddress, changeOwnerCalldata3);
        recoveryDataHash1 = keccak256(recoveryData1);
        recoveryDataHash2 = keccak256(recoveryData2);
        recoveryDataHash3 = keccak256(recoveryData3);

        bytes memory recoveryModuleInstallData1 =
            abi.encode(isInstalledContext, guardians1, guardianWeights, threshold, delay, expiry);
        bytes memory recoveryModuleInstallData2 =
            abi.encode(isInstalledContext, guardians2, guardianWeights, threshold, delay, expiry);
        bytes memory recoveryModuleInstallData3 =
            abi.encode(isInstalledContext, guardians3, guardianWeights, threshold, delay, expiry);

        // Install modules for account 1
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1)
        });
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: recoveryModuleInstallData1
        });

        // Install modules for account 2
        instance2.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner2)
        });
        instance2.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: recoveryModuleInstallData2
        });

        // Install modules for account 3
        instance3.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner3)
        });
        instance3.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: recoveryModuleInstallData3
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
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));

        bytes32 commandHandlerSalt = bytes32(uint256(0));
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        (emailRecoveryModuleAddress, commandHandlerAddress) = emailRecoveryFactory
            .deployEmailRecoveryModule(
            commandHandlerSalt,
            recoveryModuleSalt,
            handlerBytecode,
            minimumDelay,
            killSwitchAuthorizer,
            address(dkimRegistry),
            validatorAddress,
            functionSelector
        );
        emailRecoveryModule = EmailRecoveryModule(emailRecoveryModuleAddress);

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

        // // 5- verify that only the killSwitchAuthorizer can set the transaction initiator
        // emailRecoveryModule.setTransactionInitiator(address(this), true);

        // // 6- confirm that it does not work before 6 months when the transaction initiator flag is not true
        // // (Expect 15 tests to fail under this condition.)
        // vm.warp(block.timestamp + 7_884_000); // 3 months

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress1
            );
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress2
            );
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress3
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
