// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import { EmailAuth, EmailAuthMsg } from "@zk-email/ether-email-auth-contracts/src/EmailAuth.sol";
import { Verifier, EmailProof } from "@zk-email/ether-email-auth-contracts/src/utils/Verifier.sol";
import { DeploymentHelper } from "./DeploymentHelper.sol";

contract StructHelper is DeploymentHelper {
    function buildEmailAuthMsg() public returns (EmailAuthMsg memory emailAuthMsg) {
        bytes[] memory commandParams = new bytes[](2);
        commandParams[0] = abi.encode(1 ether);
        commandParams[1] = abi.encode("0x0000000000000000000000000000000000000020");

        EmailProof memory emailProof = EmailProof({
            domainName: "gmail.com",
            publicKeyHash: publicKeyHash,
            timestamp: 1_694_989_812,
            maskedCommand: "Send 1 ETH to 0x0000000000000000000000000000000000000020",
            emailNullifier: emailNullifier,
            accountSalt: accountSalt,
            isCodeExist: true,
            proof: mockProof
        });

        emailAuthMsg = EmailAuthMsg({
            templateId: templateId,
            commandParams: commandParams,
            skippedCommandPrefix: 0,
            proof: emailProof
        });

        vm.mockCall(
            address(verifier),
            abi.encodeCall(Verifier.verifyEmailProof, (emailProof)),
            abi.encode(true)
        );
    }
}
