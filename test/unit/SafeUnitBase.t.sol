// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/accounts/common/interfaces/IERC7579Module.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { BaseTest, CommandHandlerType } from "../Base.t.sol";

abstract contract SafeUnitBase is BaseTest {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    EmailRecoveryFactory public emailRecoveryFactory;
    address public commandHandlerAddress;
    UniversalEmailRecoveryModule public emailRecoveryModule;
    address public emailRecoveryModuleAddress;

    function setUp() public virtual override {
        if (!isAccountTypeSafe()) {
            return;
        }
        super.setUp();

        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(
                accountAddress1,
                isInstalledContext,
                functionSelector,
                guardians1,
                guardianWeights,
                threshold,
                delay,
                expiry
            )
        });
    }

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

        emailRecoveryModule = new UniversalEmailRecoveryModule(
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
        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));
        recoveryCalldata = abi.encodeWithSelector(functionSelector, address(1), owner1, newOwner1);
        recoveryData = abi.encode(accountAddress1, recoveryCalldata);
        recoveryDataHash = keccak256(recoveryData);
    }
}
