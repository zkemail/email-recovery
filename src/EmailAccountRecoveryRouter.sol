// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import { EmailAuthMsg } from "ether-email-auth/packages/contracts/src/EmailAuth.sol";
import { IEmailAccountRecovery } from "./interfaces/IEmailAccountRecovery.sol";

/**
 * Helper contract that routes relayer calls to correct EmailAccountRecovery implementation
 */
contract EmailAccountRecoveryRouter {
    address public immutable EMAIL_ACCOUNT_RECOVERY_IMPL;

    constructor(address _emailAccountRecoveryImpl) {
        EMAIL_ACCOUNT_RECOVERY_IMPL = _emailAccountRecoveryImpl;
    }

    function verifier() external view returns (address) {
        return IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).verifier();
    }

    function dkim() external view returns (address) {
        return IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).dkim();
    }

    function emailAuthImplementation() external view returns (address) {
        return IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).emailAuthImplementation();
    }

    function acceptanceSubjectTemplates() external view returns (string[][] memory) {
        return IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).acceptanceSubjectTemplates();
    }

    function recoverySubjectTemplates() external view returns (string[][] memory) {
        return IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).recoverySubjectTemplates();
    }

    function computeEmailAuthAddress(bytes32 accountSalt) external view returns (address) {
        return
            IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).computeEmailAuthAddress(accountSalt);
    }

    function computeAcceptanceTemplateId(uint256 templateIdx) external view returns (uint256) {
        return IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).computeAcceptanceTemplateId(
            templateIdx
        );
    }

    function computeRecoveryTemplateId(uint256 templateIdx) external view returns (uint256) {
        return IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).computeRecoveryTemplateId(
            templateIdx
        );
    }

    function handleAcceptance(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external {
        IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).handleAcceptance(
            emailAuthMsg, templateIdx
        );
    }

    function handleRecovery(EmailAuthMsg memory emailAuthMsg, uint256 templateIdx) external {
        IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).handleRecovery(emailAuthMsg, templateIdx);
    }

    function completeRecovery() external {
        IEmailAccountRecovery(EMAIL_ACCOUNT_RECOVERY_IMPL).completeRecovery();
    }
}
