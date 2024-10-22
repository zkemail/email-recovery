// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { BaseTest, CommandHandlerType } from "../../../Base.t.sol";

abstract contract OwnableValidatorRecovery_EmailRecoveryModule_Base is BaseTest {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
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
            address(dkimRegistry),
            validatorAddress,
            functionSelector
        );
        emailRecoveryModule = EmailRecoveryModule(emailRecoveryModuleAddress);

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
