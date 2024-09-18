// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { AccountInstance, ModuleKitHelpers, ModuleKitUserOp } from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_EXECUTOR, MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";
import { ECDSAOwnedDKIMRegistry } from
    "@zk-email/ether-email-auth-contracts/src/utils/ECDSAOwnedDKIMRegistry.sol";
import { CommandUtils } from "@zk-email/ether-email-auth-contracts/src/libraries/CommandUtils.sol";
import {
    EmailAuth,
    EmailAuthMsg,
    EmailProof
} from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import { BaseTest } from "test/Base.t.sol";
import { EmailRecoveryCommandHandler } from "src/handlers/EmailRecoveryCommandHandler.sol";
import { UniversalEmailRecoveryModuleHarness } from "./UniversalEmailRecoveryModuleHarness.sol";
import { EmailRecoveryManager } from "src/EmailRecoveryManager.sol";
import { EmailRecoveryFactory } from "src/factories/EmailRecoveryFactory.sol";
import { EmailRecoveryUniversalFactory } from "src/factories/EmailRecoveryUniversalFactory.sol";
import { OwnableValidator } from "src/test/OwnableValidator.sol";
import { MockGroth16Verifier } from "src/test/MockGroth16Verifier.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract UnitBase is BaseTest {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;
    using Strings for uint256;

    EmailRecoveryFactory emailRecoveryFactory;
    EmailRecoveryUniversalFactory emailRecoveryUniversalFactory;
    EmailRecoveryCommandHandler emailRecoveryHandler;
    UniversalEmailRecoveryModuleHarness emailRecoveryModule;

    address emailRecoveryModuleAddress;

    bytes isInstalledContext;
    bytes4 functionSelector;
    bytes recoveryData;
    bytes32 recoveryDataHash;

    function setUp() public virtual override {
        super.setUp();

        isInstalledContext = bytes("0");
        functionSelector = bytes4(keccak256(bytes("changeOwner(address)")));
        bytes memory changeOwnerCalldata = abi.encodeWithSelector(functionSelector, newOwner1);
        recoveryData = abi.encode(validatorAddress, changeOwnerCalldata);
        recoveryDataHash = keccak256(recoveryData);

        // Install modules
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: validatorAddress,
            data: abi.encode(owner1)
        });
        instance1.installModule({
            moduleTypeId: MODULE_TYPE_EXECUTOR,
            module: emailRecoveryModuleAddress,
            data: abi.encode(
                validatorAddress,
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
        emailRecoveryHandler = new EmailRecoveryCommandHandler();
        emailRecoveryFactory = new EmailRecoveryFactory(address(verifier), address(emailAuthImpl));
        emailRecoveryUniversalFactory =
            new EmailRecoveryUniversalFactory(address(verifier), address(emailAuthImpl));

        emailRecoveryModule = new UniversalEmailRecoveryModuleHarness(
            address(verifier),
            address(dkimRegistry),
            address(emailAuthImpl),
            address(emailRecoveryHandler)
        );
        emailRecoveryModuleAddress = address(emailRecoveryModule);
    }

    function acceptanceCommandTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](5);
        templates[0][0] = "Accept";
        templates[0][1] = "guardian";
        templates[0][2] = "request";
        templates[0][3] = "for";
        templates[0][4] = "{ethAddr}";
        return templates;
    }

    function recoveryCommandTemplates() public pure returns (string[][] memory) {
        string[][] memory templates = new string[][](1);
        templates[0] = new string[](7);
        templates[0][0] = "Recover";
        templates[0][1] = "account";
        templates[0][2] = "{ethAddr}";
        templates[0][3] = "using";
        templates[0][4] = "recovery";
        templates[0][5] = "hash";
        templates[0][6] = "{string}";
        return templates;
    }

    function handleRecovery(bytes32 _recoveryDataHash, bytes32 accountSalt) public {
        string memory accountString = CommandUtils.addressToChecksumHexString(accountAddress1);
        string memory recoveryDataHashString = uint256(_recoveryDataHash).toHexString(32);

        string memory commandPart1 = string.concat("Recover account ", accountString);
        string memory commandPart2 = string.concat(" using recovery hash ", recoveryDataHashString);
        string memory command = string.concat(commandPart1, commandPart2);

        bytes32 nullifier = keccak256(abi.encode("nullifier 2"));
        EmailProof memory emailProof = generateMockEmailProof(command, nullifier, accountSalt);

        bytes[] memory commandParamsForRecovery = new bytes[](2);
        commandParamsForRecovery[0] = abi.encode(accountAddress1);
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
