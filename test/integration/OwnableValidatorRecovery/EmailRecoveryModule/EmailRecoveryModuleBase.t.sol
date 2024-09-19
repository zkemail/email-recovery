// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryModule } from "src/modules/EmailRecoveryModule.sol";
import { IntegrationBase } from "../../IntegrationBase.t.sol";

abstract contract OwnableValidatorRecovery_EmailRecoveryModule_Base is IntegrationBase {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;
    using Strings for address;

    EmailRecoveryFactory public emailRecoveryFactory;
    EmailRecoveryCommandHandler public emailRecoveryHandler;
    EmailRecoveryModule public emailRecoveryModule;

    address public emailRecoveryModuleAddress;

    bytes public isInstalledContext;
    bytes4 public constant functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
    bytes public recoveryData1;
    bytes public recoveryData2;
    bytes public recoveryData3;
    bytes32 public recoveryDataHash1;
    bytes32 public recoveryDataHash2;
    bytes32 public recoveryDataHash3;

    function setUp() public virtual override {
        super.setUp();

        isInstalledContext = bytes("0");

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

    function deployModule() public override {
        // Deploy handler, manager and module
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));
        emailRecoveryHandler = new EmailRecoveryCommandHandler();

        // Deploy EmailRecoveryManager & EmailRecoveryModule
        bytes32 commandHandlerSalt = bytes32(uint256(0));
        bytes32 recoveryModuleSalt = bytes32(uint256(0));
        bytes memory commandHandlerBytecode = type(EmailRecoveryCommandHandler).creationCode;
        (emailRecoveryModuleAddress,) = emailRecoveryFactory.deployEmailRecoveryModule(
            commandHandlerSalt,
            recoveryModuleSalt,
            commandHandlerBytecode,
            address(dkimRegistry),
            validatorAddress,
            functionSelector
        );
        emailRecoveryModule = EmailRecoveryModule(emailRecoveryModuleAddress);
    }
}
