// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { EmailAuthMsg, EmailProof } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Create2 } from "@openzeppelin/contracts/utils/Create2.sol";

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { SafeProxy } from "@safe-global/safe-contracts/contracts/proxies/SafeProxy.sol";
import { SafeEmailRecoveryModuleHarness } from "test/unit/SafeEmailRecoveryModuleHarness.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { BaseTest, CommandHandlerType } from "../../Base.t.sol";
import { IEmailRecoveryModule } from "../../Base.t.sol";

abstract contract SafeNativeIntegrationBase is BaseTest {
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    SafeEmailRecoveryModuleHarness public emailRecoveryModule;
    address public emailRecoveryModuleAddress;
    Safe public safeSingleton;
    Safe public safe;
    address public commandHandlerAddress;

    function setUp() public virtual override {
        if (!isAccountTypeSafe()) {
            return;
        }
        super.setUp();

        safeSingleton = new Safe();
        SafeProxy safeProxy = new SafeProxy(address(safeSingleton));
        safe = Safe(payable(address(safeProxy)));
        accountAddress1 = address(safe);

        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            AccountHidingRecoveryCommandHandler(commandHandlerAddress).storeAccountHash(
                accountAddress1
            );
        }

        // Overwrite the default values
        guardians1[0] = emailRecoveryModule.computeEmailAuthAddress(accountAddress1, accountSalt1);
        guardians1[1] = emailRecoveryModule.computeEmailAuthAddress(accountAddress1, accountSalt2);
        guardians1[2] = emailRecoveryModule.computeEmailAuthAddress(accountAddress1, accountSalt3);

        address[] memory owners = new address[](1);
        owners[0] = owner1;

        safe.setup(
            owners, 1, address(0), bytes("0"), address(0), address(0), 0, payable(address(0))
        );

        vm.startPrank(accountAddress1);
        safe.enableModule(address(emailRecoveryModule));
        vm.stopPrank();
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

        emailRecoveryModule = new SafeEmailRecoveryModuleHarness(
            address(verifier),
            address(eoaVerifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(eoaAuthImpl),
            commandHandlerAddress,
            minimumDelay,
            killSwitchAuthorizer
        );
        emailRecoveryModuleAddress = address(emailRecoveryModule);
    }

    function getAccountSaltForGuardian(address guardian) public view returns (bytes32) {
        if (guardian == guardians1[0]) {
            return accountSalt1;
        }
        if (guardian == guardians1[1]) {
            return accountSalt2;
        }
        if (guardian == guardians1[2]) {
            return accountSalt3;
        }

        /* solhint-disable-next-line gas-custom-errors, custom-errors  */
        revert("Invalid guardian address");
    }

    function getAcceptanceEmailAuthMessageWithAccountSalt(
        address account,
        address guardian,
        address _emailRecoveryModule,
        bytes32 optionalAccountSalt
    )
        public
        override
        returns (EmailAuthMsg memory)
    {
        string memory command;
        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            bytes32 accountHash = keccak256(abi.encodePacked(account));
            string memory accountHashString = uint256(accountHash).toHexString(32);
            command = string.concat("Accept guardian request for ", accountHashString);
            commandParamsForAcceptance[0] = abi.encode(accountHashString);
        } else {
            string memory accountString = CommandUtils.addressToChecksumHexString(account);
            command = string.concat("Accept guardian request for ", accountString);
            commandParamsForAcceptance[0] = abi.encode(account);
        }

        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        return EmailAuthMsg({
            templateId: IEmailRecoveryModule(_emailRecoveryModule).computeAcceptanceTemplateId(
                templateIdx
            ),
            commandParams: commandParamsForAcceptance,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }

    function handleRecoveryForSafe(
        address account,
        bytes32 recoveryDataHash,
        address guardian
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, recoveryDataHash, guardian);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        bytes32 recoveryDataHash,
        address guardian
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory command;
        bytes[] memory commandParamsForRecovery = new bytes[](2);
        if (getCommandHandlerType() == CommandHandlerType.AccountHidingRecoveryCommandHandler) {
            bytes32 accountHash = keccak256(abi.encodePacked(account));
            string memory accountHashString = uint256(accountHash).toHexString(32);
            string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
            string memory commandPart1 = string.concat("Recover account ", accountHashString);
            string memory commandPart2 =
                string.concat(" using recovery hash ", recoveryDataHashString);
            command = string.concat(commandPart1, commandPart2);

            commandParamsForRecovery = new bytes[](2);
            commandParamsForRecovery[0] = abi.encode(accountHashString);
            commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);
        }
        if (getCommandHandlerType() == CommandHandlerType.EmailRecoveryCommandHandler) {
            string memory accountString = CommandUtils.addressToChecksumHexString(account);
            string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
            string memory commandPart1 = string.concat("Recover account ", accountString);
            string memory commandPart2 =
                string.concat(" using recovery hash ", recoveryDataHashString);
            command = string.concat(commandPart1, commandPart2);

            commandParamsForRecovery = new bytes[](2);
            commandParamsForRecovery[0] = abi.encode(account);
            commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);
        }

        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt = getAccountSaltForGuardian(guardian);

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

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
