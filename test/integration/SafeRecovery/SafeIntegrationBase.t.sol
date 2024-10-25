// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg, EmailProof } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { BaseTest, CommandHandlerType } from "../../Base.t.sol";

abstract contract SafeIntegrationBase is BaseTest {
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

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
                address(accountAddress1),
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
            minimumDelay
        );
        emailRecoveryModuleAddress = address(emailRecoveryModule);

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress1
            );
        }
    }

    function handleRecoveryForSafe(
        address account,
        address oldOwner,
        address newOwner1,
        address guardian
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, oldOwner, newOwner1, guardian);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        address oldOwner,
        address newOwner1,
        address guardian
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = CommandUtils.addressToChecksumHexString(account);
        string memory oldOwnerString = CommandUtils.addressToChecksumHexString(oldOwner);
        string memory newOwnerString = CommandUtils.addressToChecksumHexString(newOwner1);

        string memory command = string.concat(
            "Recover account ",
            accountString,
            " from old owner ",
            oldOwnerString,
            " to new owner ",
            newOwnerString
        );
        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt = getAccountSaltForGuardian(account, guardian);

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForRecovery = new bytes[](3);
        commandParamsForRecovery[0] = abi.encode(account);
        commandParamsForRecovery[1] = abi.encode(oldOwner);
        commandParamsForRecovery[2] = abi.encode(newOwner1);

        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }

    function setRecoveryData() public override {
        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));
        recoveryCalldata = abi.encodeWithSelector(functionSelector, address(1), owner1, newOwner1);
        recoveryData = abi.encode(accountAddress1, recoveryCalldata);
        recoveryDataHash = keccak256(recoveryData);
    }
}
