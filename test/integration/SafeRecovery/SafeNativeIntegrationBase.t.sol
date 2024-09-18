// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg, EmailProof } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { Safe } from "@safe-global/safe-contracts/contracts/Safe.sol";
import { SafeProxy } from "@safe-global/safe-contracts/contracts/proxies/SafeProxy.sol";
import { SafeEmailRecoveryModule } from "src/modules/SafeEmailRecoveryModule.sol";
import { AccountHidingRecoveryCommandHandler } from
    "src/handlers/AccountHidingRecoveryCommandHandler.sol";
import { IntegrationBase } from "../IntegrationBase.t.sol";
import { IEmailRecoveryModule } from "../../Base.t.sol";

abstract contract SafeNativeIntegrationBase is IntegrationBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    SafeEmailRecoveryModule emailRecoveryModule;
    address emailRecoveryModuleAddress;
    Safe public safeSingleton;
    Safe public safe;
    address public safeAddress;
    bytes isInstalledContext;
    bytes4 functionSelector;
    address commandHandler;

    /**
     * Helper function to return if current account type is safe or not
     */
    function isAccountTypeSafe() public view returns (bool) {
        string memory currentAccountType = vm.envOr("ACCOUNT_TYPE", string(""));
        if (Strings.equal(currentAccountType, "SAFE")) {
            return true;
        } else {
            return false;
        }
    }

    function skipIfNotSafeAccountType() public {
        if (isAccountTypeSafe()) {
            vm.skip(false);
        } else {
            vm.skip(true);
        }
    }

    function setUp() public virtual override {
        if (!isAccountTypeSafe()) {
            return;
        }
        super.setUp();

        safeSingleton = new Safe();
        SafeProxy safeProxy = new SafeProxy(address(safeSingleton));
        safe = Safe(payable(address(safeProxy)));
        safeAddress = address(safe);

        // Overwrite the default values
        guardians1[0] = emailRecoveryModule.computeEmailAuthAddress(safeAddress, accountSalt1);
        guardians1[1] = emailRecoveryModule.computeEmailAuthAddress(safeAddress, accountSalt2);
        guardians1[2] = emailRecoveryModule.computeEmailAuthAddress(safeAddress, accountSalt3);

        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

        address[] memory owners = new address[](1);
        owners[0] = owner1;

        safe.setup(
            owners, 1, address(0), bytes("0"), address(0), address(0), 0, payable(address(0))
        );

        vm.startPrank(safeAddress);
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

    function deployModule() public override {
        // Deploy handler, manager and module
        commandHandler = address(new AccountHidingRecoveryCommandHandler());
        emailRecoveryModule = new SafeEmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(commandHandler)
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

        revert("Invalid guardian address");
    }

    function getAcceptanceEmailAuthMessageWithAccountSalt(
        address account,
        address guardian,
        address emailRecoveryModule,
        bytes32 optionalAccountSalt
    )
        public
        override
        returns (EmailAuthMsg memory)
    {
        bytes32 accountHash = keccak256(abi.encodePacked(account));
        string memory accountHashString = uint256(accountHash).toHexString(32);
        string memory command = string.concat("Accept guardian request for ", accountHashString);
        bytes32 nullifier = generateNewNullifier();

        bytes32 accountSalt;
        if (optionalAccountSalt == bytes32(0)) {
            accountSalt = getAccountSaltForGuardian(account, guardian);
        } else {
            accountSalt = optionalAccountSalt;
        }

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(accountHashString);
        return EmailAuthMsg({
            templateId: IEmailRecoveryModule(emailRecoveryModule).computeAcceptanceTemplateId(
                templateIdx
            ),
            commandParams: commandParamsForAcceptance,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }

    function handleRecovery(address account, bytes32 recoveryDataHash, address guardian) public {
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
        bytes32 accountHash = keccak256(abi.encodePacked(account));
        string memory accountHashString = uint256(accountHash).toHexString(32);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);
        string memory commandPart1 = string.concat("Recover account ", accountHashString);
        string memory commandPart2 = string.concat(" using recovery hash ", recoveryDataHashString);
        string memory command = string.concat(commandPart1, commandPart2);

        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt = getAccountSaltForGuardian(guardian);

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(accountHashString);
        commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);
        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }
}
