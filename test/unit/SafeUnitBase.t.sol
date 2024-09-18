// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { ModuleKitHelpers } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR } from "modulekit/external/ERC7579.sol";
import { EmailAuthMsg, EmailProof } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { UniversalEmailRecoveryModule } from "src/modules/UniversalEmailRecoveryModule.sol";
import { SafeRecoveryCommandHandlerHarness } from "./SafeRecoveryCommandHandlerHarness.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { IntegrationBase } from "../integration/IntegrationBase.t.sol";

abstract contract SafeUnitBase is IntegrationBase {
    using ModuleKitHelpers for *;
    using Strings for uint256;

    EmailRecoveryFactory emailRecoveryFactory;
    SafeRecoveryCommandHandlerHarness safeRecoveryCommandHandler;
    UniversalEmailRecoveryModule emailRecoveryModule;
    address emailRecoveryModuleAddress;

    bytes4 functionSelector;
    bytes recoveryData;
    bytes32 recoveryDataHash;
    bytes isInstalledContext;

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

        functionSelector = bytes4(keccak256(bytes("swapOwner(address,address,address)")));
        address previousOwnerInLinkedList = address(1);
        bytes memory swapOwnerCalldata = abi.encodeWithSignature(
            "swapOwner(address,address,address)", previousOwnerInLinkedList, owner1, newOwner1
        );
        recoveryData = abi.encode(accountAddress1, swapOwnerCalldata);
        recoveryDataHash = keccak256(recoveryData);
        isInstalledContext = bytes("0");

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

    function deployModule() public override {
        // Deploy handler, manager and module
        safeRecoveryCommandHandler = new SafeRecoveryCommandHandlerHarness();
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));

        emailRecoveryModule = new UniversalEmailRecoveryModule(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(safeRecoveryCommandHandler)
        );
        emailRecoveryModuleAddress = address(emailRecoveryModule);
    }

    function handleRecovery(address account, bytes32 accountSalt) public {
        string memory accountString = CommandUtils.addressToChecksumHexString(account);
        string memory recoveryDataHashString = uint256(recoveryDataHash).toHexString(32);

        string memory commandPart1 = string.concat("Recover account ", accountString);
        string memory commandPart2 = string.concat(" using recovery hash ", recoveryDataHashString);
        string memory command = string.concat(commandPart1, commandPart2);
        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        uint256 templateIdx = 0;

        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(account);
        commandParamsForRecovery[1] = abi.encode(recoveryDataHashString);

        EmailAuthMsg memory emailAuthMsg = EmailAuthMsg({
            templateId: emailRecoveryModule.computeRecoveryTemplateId(templateIdx),
            commandParams: commandParamsForRecovery,
            skippedCommandPrefix: 0,
            proof: emailProof
        });
        emailRecoveryModule.handleRecovery(emailAuthMsg, templateIdx);
    }
}
