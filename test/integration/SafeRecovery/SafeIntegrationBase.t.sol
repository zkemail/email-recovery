// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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
    address emailRecoveryModuleAddress;

    bytes isInstalledContext;
    bytes4 functionSelector;

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

    function setUp() public virtual override {
        if (!isAccountTypeSafe()) {
            return;
        }
        super.setUp();

        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));

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

    function deployModule() public override {
        // Deploy handler, manager and module
        safeRecoveryCommandHandler = new SafeRecoveryCommandHandler();

        emailRecoveryModule = new UniversalEmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(safeRecoveryCommandHandler)
        );
        emailRecoveryModuleAddress = address(emailRecoveryModule);
    }

    function handleRecovery(
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
}
