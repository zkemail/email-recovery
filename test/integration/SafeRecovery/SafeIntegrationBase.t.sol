// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { console2 } from "forge-std/console2.sol";

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg, EmailProof } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { SafeRecoveryCommandHandler } from "src/handlers/SafeRecoveryCommandHandler.sol";
import { IntegrationBase } from "../IntegrationBase.t.sol";

abstract contract SafeIntegrationBase is IntegrationBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;
    using Strings for address;

    SafeRecoveryCommandHandler safeRecoveryCommandHandler;
    UniversalEmailRecoveryModule emailRecoveryModule;
    address recoveryModuleAddress;

    bytes isInstalledContext;
    bytes4 functionSelector;

    uint256 nullifierCount;

    /**
     * Helper function to return if current account type is safe or not
     */
    function isAccountTypeSafe() public returns (bool) {
        string memory currentAccountType = vm.envOr("ACCOUNT_TYPE", string(""));
        if (Strings.equal(currentAccountType, "SAFE")) {
            return true;
        } else {
            return false;
        }
    }

    function setUp() public virtual override {
        if (!isAccountTypeSafe()) {
            return;
        }
        super.setUp();

        // Deploy handler, manager and module
        safeRecoveryCommandHandler = new SafeRecoveryCommandHandler();

        emailRecoveryModule = new UniversalEmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(safeRecoveryCommandHandler)
        );
        recoveryModuleAddress = address(emailRecoveryModule);

        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

        // Compute guardian addresses
        guardians1 = new address[](3);
        guardians1[0] = emailRecoveryModule.computeEmailAuthAddress(accountAddress1, accountSalt1);
        guardians1[1] = emailRecoveryModule.computeEmailAuthAddress(accountAddress1, accountSalt2);
        guardians1[2] = emailRecoveryModule.computeEmailAuthAddress(accountAddress1, accountSalt3);
        guardians2 = new address[](3);
        guardians2[0] = emailRecoveryModule.computeEmailAuthAddress(instance2.account, accountSalt1);
        guardians2[1] = emailRecoveryModule.computeEmailAuthAddress(instance2.account, accountSalt2);
        guardians2[2] = emailRecoveryModule.computeEmailAuthAddress(instance2.account, accountSalt3);
        guardians3 = new address[](3);
        guardians3[0] = emailRecoveryModule.computeEmailAuthAddress(instance3.account, accountSalt1);
        guardians3[1] = emailRecoveryModule.computeEmailAuthAddress(instance3.account, accountSalt2);
        guardians3[2] = emailRecoveryModule.computeEmailAuthAddress(instance3.account, accountSalt3);

        vm.prank(accountAddress1);
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: recoveryModuleAddress,
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
        vm.stopPrank();
    }

    function generateMockEmailProof(
        string memory command,
        bytes32 nullifier,
        bytes32 accountSalt
    )
        public
        view
        returns (EmailProof memory)
    {
        EmailProof memory emailProof;
        emailProof.domainName = "gmail.com";
        emailProof.publicKeyHash = bytes32(
            vm.parseUint(
                "6632353713085157925504008443078919716322386156160602218536961028046468237192"
            )
        );
        emailProof.timestamp = block.timestamp;
        emailProof.maskedCommand = command;
        emailProof.emailNullifier = nullifier;
        emailProof.accountSalt = accountSalt;
        emailProof.isCodeExist = true;
        emailProof.proof = bytes("0");

        return emailProof;
    }

    function getAccountSaltForGuardian(address guardian) public returns (bytes32) {
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

    function generateNewNullifier() public returns (bytes32) {
        return keccak256(abi.encode(nullifierCount++));
    }

    function acceptGuardian(address account, address guardian) public {
        EmailAuthMsg memory emailAuthMsg = getAcceptanceEmailAuthMessage(account, guardian);
        emailRecoveryModule.handleAcceptance(emailAuthMsg, templateIdx);
    }

    function getAcceptanceEmailAuthMessage(
        address account,
        address guardian
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = CommandUtils.addressToChecksumHexString(account);
        string memory command = string.concat("Accept guardian request for ", accountString);
        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt = getAccountSaltForGuardian(guardian);

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForAcceptance = new bytes[](1);
        commandParamsForAcceptance[0] = abi.encode(account);
        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeAcceptanceTemplateId(templateIdx),
            commandParams: commandParamsForAcceptance,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }

    function handleRecovery(
        address account,
        address oldOwner,
        address newOwner,
        address guardian
    )
        public
    {
        EmailAuthMsg memory emailAuthMsg =
            getRecoveryEmailAuthMessage(account, oldOwner, newOwner, guardian);
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }

    function getRecoveryEmailAuthMessage(
        address account,
        address oldOwner,
        address newOwner,
        address guardian
    )
        public
        returns (EmailAuthMsg memory)
    {
        string memory accountString = CommandUtils.addressToChecksumHexString(account);
        string memory oldOwnerString = CommandUtils.addressToChecksumHexString(oldOwner);
        string memory newOwnerString = CommandUtils.addressToChecksumHexString(newOwner);

        string memory command = string.concat(
            "Recover account ",
            accountString,
            " from old owner ",
            oldOwnerString,
            " to new owner ",
            newOwnerString
        );
        bytes32 nullifier = generateNewNullifier();
        bytes32 accountSalt = getAccountSaltForGuardian(guardian);

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForRecovery = new bytes[](3);
        commandParamsForRecovery[0] = abi.encode(account);
        commandParamsForRecovery[1] = abi.encode(oldOwner);
        commandParamsForRecovery[2] = abi.encode(newOwner);

        return EmailAuthMsg({
            templateId: emailRecoveryModule.computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
    }
}
